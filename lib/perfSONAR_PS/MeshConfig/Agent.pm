package perfSONAR_PS::MeshConfig::Agent;

use strict;
use warnings;

our $VERSION = 3.1;

use Config::General;
use File::Basename;
use Log::Log4perl qw(get_logger);
use MIME::Lite;
use Params::Validate qw(:all);
use URI::Split qw(uri_split);
use FreezeThaw qw(freeze thaw);

use perfSONAR_PS::Utils::Host qw(get_ips);
use perfSONAR_PS::Utils::DNS qw(resolve_address reverse_dns);
use perfSONAR_PS::NPToolkit::ConfigManager::Utils qw(restart_service save_file);

use Data::Validate::Domain qw(is_hostname);
use Data::Validate::IP qw(is_ipv4);
use Net::IP;

use perfSONAR_PS::MeshConfig::Utils qw(load_mesh);

use perfSONAR_PS::MeshConfig::Config::Mesh;
use perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting;

use perfSONAR_PS::NPToolkit::Services::ServicesMap qw(get_service_object);

use Module::Load;

use Moose;

has 'use_toolkit'            => (is => 'rw', isa => 'Bool');
has 'restart_services'       => (is => 'rw', isa => 'Bool');

has 'meshes'                 => (is => 'rw', isa => 'ArrayRef[HashRef]', default => sub { [] });

has 'regular_testing_conf'   => (is => 'rw', isa => 'Str', default => "/opt/perfsonar_ps/regular_testing/etc/regular_testing.conf");
has 'force_bwctl_owamp'      => (is => 'rw', isa => 'Bool', default => 0);

has 'addresses'              => (is => 'rw', isa => 'ArrayRef[Str]');

has 'send_error_emails'      => (is => 'rw', isa => 'Bool', default => 1);

has 'from_address'           => (is => 'rw', isa => 'Str');
has 'administrator_emails'   => (is => 'rw', isa => 'ArrayRef[Str]');

has 'skip_redundant_tests'   => (is => 'rw', isa => 'Bool', default=>1);

has 'errors'                 => (is => 'rw', isa => 'ArrayRef[HashRef]');

my $logger = get_logger(__PACKAGE__);

sub init {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         meshes => 1,
                                         use_toolkit => 0,
                                         restart_services => 0,
                                         validate_certificate => 0,
                                         ca_certificate_file => 0,
                                         ca_certificate_path => 0,
                                         use_regular_testing => 0,
                                         regular_testing_conf => 0,
                                         force_bwctl_owamp    => 0,
                                         traceroute_master_conf => 0,
                                         owmesh_conf => 0,
                                         pinger_landmarks => 0,
                                         skip_redundant_tests => 0,
                                         addresses => 0,
                                         from_address => 0,
                                         administrator_emails => 0,
                                         send_error_emails    => 0,
                                      });
    foreach my $key (keys %$parameters) {
        if (defined $parameters->{$key}) {
            $self->$key($parameters->{$key});
        }
    }

    return;
}

sub run {
    my ($self) = @_;

    unless ($self->addresses) {
        $self->addresses($self->__get_addresses());
    }

    if (scalar(@{ $self->addresses }) == 0) {
        my $msg = "No addresses for this host";
        $logger->error($msg);
        $self->__add_error({ error_msg => $msg });
        return;
    }


    $self->__configure_host();

    $self->__send_error_messages();

    return;
}

sub __send_error_messages {
    my ($self) = @_;

    unless ($self->send_error_emails) {
        $logger->debug("Sending error messages is disabled");
        return;
    }

    if (not $self->errors or scalar(@{ $self->errors }) == 0) {
        $logger->debug("No errors reported");
        return;
    }


    # Build one email for each group of recipients. We may want to do this
    # per-recipient.
    my %emails_by_to = ();
    foreach my $error (@{ $self->errors }) {
        my @to_addresses = $self->__get_administrator_emails({ local => $self->administrator_emails, mesh => $error->{mesh}, host => $error->{host} });
        if (scalar(@to_addresses) == 0) {
            $logger->debug("No email address to send error message to: ".$error->{error_msg});
            next;
        }

        my $full_error_msg = "Mesh Error:\n";
        $full_error_msg .= "  Mesh: ".($error->{mesh}?$error->{mesh}->description:"")."\n";
        $full_error_msg .= "  Host: ".($error->{host}?$error->{host}->addresses->[0]->address:"")."\n";
        $full_error_msg .= "  Error: ".$error->{error_msg}."\n\n";

        my $hash_key = join("|", @to_addresses);

        unless ($emails_by_to{$hash_key}) {
            $emails_by_to{$hash_key} = { to => \@to_addresses, body => "" };
        }

        $emails_by_to{$hash_key}->{body} .= $full_error_msg;
    }

    my $from_address = $self->from_address;
    unless ($from_address) {
        my $hostname = `hostname -f 2> /dev/null`;
        chomp($hostname);
        unless($hostname) {
            $hostname = `hostname 2> /dev/null`;
            chomp($hostname);
        }
        unless($hostname) {
            $hostname = "localhost";
        }

        $from_address = "mesh_agent@".$hostname;
    }
 
    foreach my $email (values %emails_by_to) {
        $logger->debug("Sending email to: ".join(', ', @{ $email->{to} }).": ".$email->{body});
        my $msg = MIME::Lite->new(
                From     => $from_address,
                To       => $email->{to},
                Subject  =>'Mesh Errors',
                Data     => $email->{body},
            );

        unless ($msg->send) {
            $logger->error("Problem sending email to: ".join(', ', @{ $email->{to} }));
        }
    }

    return;
}

sub __get_administrator_emails {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         local => 0,
                                         mesh => 0,
                                         host => 0,
                                      });

    my $local = $parameters->{local};
    my $mesh  = $parameters->{mesh};
    my $host  = $parameters->{host};

    my %addresses = ();

    my $site = $host?$host->parent:undef;
    my $organization = $site?$site->parent:undef;

    foreach my $level ($host, $site, $organization, $mesh) { # i.e. host, site and mesh level administrators
        next unless ($level and $level->administrators);

        foreach my $admin (@{ $level->administrators }) {
            $addresses{$admin->email} = 1;
        }
    }

    if ($local) {
        foreach my $admin (@{ $local }) {
            $addresses{$admin} = 1;
        }
    }

    return keys %addresses;
}

sub __configure_host {
    my ($self) = @_;

    if (scalar(@{ $self->meshes }) == 0) {
        $logger->warn("No meshes defined in the configuration");
    }

    my $generator = perfSONAR_PS::MeshConfig::Generators::perfSONARRegularTesting->new();
    my ($status, $res) = $generator->init({ config_file => $self->regular_testing_conf,
                                            skip_duplicates => $self->skip_redundant_tests,
                                            force_bwctl_owamp => $self->force_bwctl_owamp });
    if ($status != 0) {
        my $msg = "Problem initializing Regular Testing configuration: ".$res;
        $logger->error($msg);
        $self->__add_error({ error_msg => $msg });
        return;
    }

    # The $dont_change variable lets us know at the end whether or not we
    # should go through with writing the files, and restarting the daemons. If
    # a user has specified that a mesh must exist, or no updates occur, we
    # don't change anything.
    my $dont_change = 0;

    foreach my $mesh_params (@{ $self->meshes }) {
        # Grab the mesh from the server
        my ($status, $res) = load_mesh({
                                      configuration_url => $mesh_params->{configuration_url},
                                      validate_certificate => $mesh_params->{validate_certificate},
                                      ca_certificate_file => $mesh_params->{ca_certificate_file},
                                      ca_certificate_path => $mesh_params->{ca_certificate_path},
                                   });
        if ($status != 0) {
            if ($mesh_params->{required}) {
                $dont_change = 1;
            }

            my $msg = "Problem with mesh configuration: ".$res;
            $logger->error($msg);
            $self->__add_error({ error_msg => $msg });
            next;
        }

        my $meshes = $res;

        foreach my $mesh (@$meshes) {
            # Make sure that the mesh is valid
            eval {
                $mesh->validate_mesh();
            };
            if ($@) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Invalid mesh configuration: ".$@;
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            if ($mesh->has_unknown_attributes) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Mesh has unknown attributes: ".join(", ", keys %{ $mesh->get_unknown_attributes });
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            # Find the host block associated with this machine
            my $hosts = $mesh->lookup_hosts({ addresses => $self->addresses });
            my $host_classes = $mesh->lookup_host_classes_by_addresses({ addresses => $self->addresses });

            unless ($hosts->[0] or $host_classes->[0]) {
                if ($mesh_params->{permit_non_participation}) {
                    my $msg = "This machine is not included in any tests for this mesh: ".join(", ", @{ $self->addresses });
                    $logger->info($msg);
                    next;
                }

                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Can't find any host blocks associated with the addresses on this machine: ".join(", ", @{ $self->addresses });
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, error_msg => $msg });
                next;
            }

            if (scalar(@$hosts) > 1) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Multiple 'host' elements associated with the addresses on this machine: ".join(", ", @{ $self->addresses });
                $logger->warn($msg);
            }

            my %addresses = ();

            # Add any addresses pre-configured
            foreach my $addr (@{ $self->addresses }) {
                $addresses{$addr} = 1;
            }

            # Add any addresses found in host blocks
            foreach my $host (@$hosts) {
                if ($host->has_unknown_attributes) {
                    if ($mesh_params->{required}) {
                        $dont_change = 1;
                    }

                    my $msg = "Host block associated with this machine has unknown attributes: ".join(", ", keys %{ $host->get_unknown_attributes });
                    $logger->error($msg);
                    $self->__add_error({ mesh => $mesh, error_msg => $msg });
                    next;
                }

                foreach my $addr_obj (@{ $host->addresses }) {
                    $addresses{$addr_obj->address} = 1;
                }
            }

            my @addresses = keys %addresses;

	    # Find the tests that this machine is expected to run with all the
	    # addresses obtained
            my $tests = $mesh->lookup_tests_by_addresses({ addresses => \@addresses });
            if (scalar(@$tests) == 0) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "No tests for this host to run: ".join(", ", @{ $self->addresses });
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, host => $hosts->[0], error_msg => $msg });
                next;
            }

            # Add the tests to the various service configurations
            eval {
                $generator->add_mesh_tests({ mesh => $mesh,
                                             tests => $tests,
                                             addresses => \@addresses,
                                           });
            };
            if ($@) {
                if ($mesh_params->{required}) {
                    $dont_change = 1;
                }

                my $msg = "Problem adding Regular Testing tests: $@";
                $logger->error($msg);
                $self->__add_error({ mesh => $mesh, host => $hosts->[0], error_msg => $msg });
            }
        }
    }

    if ($dont_change) {
        my $msg = "Problem with required meshes, not changing configuration";
        $logger->error($msg);
        $self->__add_error({ error_msg => $msg });
        return;
    }

    my $config = $generator->get_config();

    $status = $self->__write_file({ file => $self->regular_testing_conf, contents => $config });

    if ($status and $self->restart_services) {
        ($status, $res) = $self->__restart_service({ name => "regular_testing" });
        if ($status != 0) {
            my $msg = "Problem restarting Revular Testing: ".$res;
            $logger->error($msg);
            foreach my $mesh_params (@{ $self->meshes }) {
                $self->__add_error({ mesh => $mesh_params->{mesh}, host => $mesh_params->{host}, error_msg => $msg });
            }
        }
    }

    return;
}

sub __add_error {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { 
                                         mesh => 0,
                                         host => 0,
                                         error_msg => 1,
                                      });

    my @errors = ();
    @errors = @{ $self->errors } if ($self->errors);

    push @errors, $parameters;

    $self->errors(\@errors);

    return;
}

sub __write_file {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { file => 1, contents => 1 } );
    my $file  = $parameters->{file};
    my $contents = $parameters->{contents};

    unless ($self->__compare_file({ file => $file, contents => $contents })) {
        $logger->info($file." is unchanged.");
        return;
    }

    $logger->debug("Writing ".$file);

    eval {
        if ($self->use_toolkit) {
            my $res = save_file( { file => $file, content => $contents } );
            if ( $res == -1 ) {
                die("Couldn't save ".$file."via toolkit daemon");
            }
        } 
        else {
            open(FILE, ">".$file) or die("Couldn't open $file");
            print FILE $contents;
            close(FILE);
        }
    };
    if ($@) {
        my $msg = "Problem writing to $file: $@";
        $logger->error($msg);

        foreach my $mesh_params (@{ $self->meshes }) {
            $self->__add_error({ mesh => $mesh_params->{mesh}, host => $mesh_params->{host}, error_msg => $msg });
        }

        return;
    }

    return 1;
}

sub __compare_file {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { file => 1, contents => 1 } );
    my $file  = $parameters->{file};
    my $contents = $parameters->{contents};

    $logger->debug("Checking for changes in ".$file);

    my $differ = 1;

    if (open(FILE, $file)) {
        $logger->debug("Reading ".$file);
        my $file_contents = do { local $/; <FILE> };
        $differ = 0 if ($file_contents eq $contents);
        $logger->debug($file." changed") if ($differ);
        close(FILE);
    }

    return $differ;
}

sub __restart_service {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { name => 1 } );
    my $name  = $parameters->{name};

    eval {
        if ($self->use_toolkit) {
            my $res = restart_service( { name => $name } );
            if ( $res == -1 ) {
                die("Couldn't restart service ".$name." via toolkit daemon");
            }
        }
        else {
            my $service_obj = get_service_object($name);
            unless ($service_obj) {
                my $msg = "Invalid service: $name";
                $logger->error($msg);
                die($msg);
            }

            die if ($service_obj->restart);
        } 
    };
    if ($@) {
        my $msg = "Problem restarting $name: $@";
        $logger->error($msg);
        return (-1, $msg);
    }

    return (0, "");
}

sub __get_addresses {
    my $hostname = `hostname -f 2> /dev/null`;
    chomp($hostname);

    my @ips = get_ips();

    my %ret_addresses = ();

    my @all_addressses = ();
    @all_addressses = @ips;
    push @all_addressses, $hostname if ($hostname);

    foreach my $address (@all_addressses) {
        next if ($ret_addresses{$address});

        $ret_addresses{$address} = 1;

        if ( is_ipv4( $address ) or 
             &Net::IP::ip_is_ipv6( $address ) ) {
            my @hostnames = reverse_dns($address);

            push @all_addressses, @hostnames;
        }
        elsif ( is_hostname( $address ) ) {
            my $hostname = $address;

            my @addresses = resolve_address($hostname);

            push @all_addressses, @addresses;
        }
    }

    my @ret_addresses = keys %ret_addresses;

    return \@ret_addresses;
}
