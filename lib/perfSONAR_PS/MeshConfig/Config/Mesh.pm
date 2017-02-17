package perfSONAR_PS::MeshConfig::Config::Mesh;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);
use Net::IP;

use perfSONAR_PS::MeshConfig::Config::Administrator;
use perfSONAR_PS::MeshConfig::Config::Organization;
use perfSONAR_PS::MeshConfig::Config::MeasurementArchive;
use perfSONAR_PS::MeshConfig::Config::Test;
use perfSONAR_PS::MeshConfig::Config::HostClass;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::Mesh;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'description'          => (is => 'rw', isa => 'Str');

has 'administrators'       => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Administrator]', default => sub { [] });
has 'organizations'        => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Organization]', default => sub { [] });
has 'measurement_archives' => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::MeasurementArchive]', default => sub { [] });
has 'tests'                => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Test]', default => sub { [] });
has 'hosts'                => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Host]', default => sub { [] });
has 'host_classes'         => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::HostClass]', default => sub { [] });

sub validate_mesh {
    my ($self) = @_;

    my %hosts = ();

    my @all_hosts = ();
    push @all_hosts, @{ $self->hosts };

    foreach my $organization (@{ $self->organizations }) {
        push @all_hosts, @{ $organization->hosts };

        foreach my $site (@{ $organization->sites }) {
            push @all_hosts, @{ $site->hosts };
        }
    }

    foreach my $host (@all_hosts) {
        foreach my $addr_obj (@{ $host->addresses }) {
            my $hosts = $self->lookup_hosts({ addresses => [ $addr_obj->address ] });
            if (scalar(@$hosts) > 1) {
                die("Multiple hosts match ".$addr_obj->address);
            }
        }
    }

    foreach my $test (@{ $self->tests }) {
        my $pairs = $test->members->source_destination_pairs;
        my $has_testing_agent;

        foreach my $pair (@$pairs) {
            foreach my $direction ("source", "destination") {
                unless ($pair->{$direction}->{addr_obj}->parent->no_agent) {
                    $has_testing_agent = 1;
                    last;
                }
            }
        }

        unless ($has_testing_agent or scalar(@$pairs) == 0) {
            die("Test '".$test->description."' does not have any hosts that can actually perform the test");
        }
    }

    return;
}

sub lookup_host_class {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { name => 1 } );
    my $name       = $parameters->{name};

    foreach my $class (@{ $self->host_classes }) {
        if ($class->name eq $name) {
            return $class;
        }
    }

    return;
}

sub lookup_measurement_archive {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { type => 1 } );
    my $type       = $parameters->{type};

    foreach my $measurement_archive (@{ $self->measurement_archives }) {
        if ($measurement_archive->type eq $type) {
            return $measurement_archive;
        }
    }

    return;
}

sub lookup_measurement_archives {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { type => 1, recursive => 1  } );
    my $type       = $parameters->{type};
    my $recursive  = $parameters->{recursive};
    
    my @measurement_archives = ();
    foreach my $measurement_archive (@{ $self->measurement_archives }) {
        if ($measurement_archive->type eq $type) {
            push @measurement_archives, $measurement_archive;
        }
    }

    return \@measurement_archives;
}

sub lookup_address {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { address => 1 } );
    my $address = $parameters->{address};

    my $hosts = $self->lookup_hosts({ addresses => [ $address ] });
    foreach my $curr_host (@$hosts) {
        foreach my $curr_addr (@{ $curr_host->addresses }) {
            return $curr_addr if ($curr_addr->address eq $address);
        }
    }

    return;
}

sub lookup_host_classes_by_addresses {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { addresses => 1 } );
    my $addresses    = $parameters->{addresses};

    my %addresses = map { $_ => 1} @$addresses;

    my @host_classes = ();

    foreach my $host_class (@{ $self->host_classes }) {
        foreach my $addr (@{ $host_class->get_addresses() }) {
            if ($addresses{$addr->address}) {
                push @host_classes, $host_class;
                last;
            }
        }
    }

    return \@host_classes;
}

sub lookup_hosts {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { addresses => 1 } );
    my $addresses    = $parameters->{addresses};

    $self->cache({}) unless $self->cache;

    my $key = "lookup_hosts-".join("|", @$addresses);

    if ($self->cache->{$key}) {
        return $self->cache->{$key};
    }

    my @hosts = ();

    # Lookup all the matching 'host' elements that are direct descendents of the mesh
    push @hosts, $self->__find_matching_hosts({ element => $self, addresses => $addresses });

    foreach my $organization (@{ $self->organizations }) {
        # Lookup all the matching 'host' elements that are direct descendents of the organization
        push @hosts, $self->__find_matching_hosts({ element => $organization, addresses => $addresses });

        foreach my $site (@{ $organization->sites }) {
            # Lookup all the matching 'host' elements that are direct descendents of the site
            push @hosts, $self->__find_matching_hosts({ element => $site, addresses => $addresses });
        }
    }

    $self->cache->{$key} = \@hosts;

    return \@hosts;
}

sub __find_matching_hosts {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { element => 1, addresses => 1 } );
    my $element      = $parameters->{element};
    my $addresses    = $parameters->{addresses};

    my %addresses = ();
    foreach my $address (@$addresses) {
        $address = lc($address);

        if ($address =~ /^\[(.*)\]:(\d+)$/) {
            $addresses{$1} = 1;
        }
        elsif (&Net::IP::ip_is_ipv6( $address ) ) {
            $addresses{$address} = 1;
        }
        elsif ($address =~ /^(.*):(\d+)$/) {
            $addresses{$1} = 1;
        }
        else {
            $addresses{$address} = 1;
        }
    }

    my @matching_hosts = ();

    if ($element->hosts) {
        foreach my $host (@{ $element->hosts }) {
            my $found;

            foreach my $host_address_obj (@{ $host->addresses }) {
                my $host_address = lc($host_address_obj->address);

                next unless ($addresses{$host_address});

                $found = 1;
                last;
            }

            push @matching_hosts, $host if $found;
        }
    }

    return @matching_hosts;
}

sub lookup_tests_by_addresses {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { addresses => 1 } );
    my $addresses  = $parameters->{addresses};

    my %address_map = map { $_ => 1 } @$addresses;

    my @tests = ();

    foreach my $test (@{ $self->tests }) {
        my $pairs = $test->members->source_destination_pairs;
        foreach my $pair (@$pairs) {
            if ($address_map{$pair->{source}->{address}} or 
                $address_map{$pair->{destination}->{address}}) {
                push @tests, $test;
                last;
                #print "Pair doesn't match: ".$pair->{source}->{address}." -> ".$pair->{destination}->{address}."\n";
            }
        }
    }

    return \@tests;
}

1;

__END__

=head1 SEE ALSO

To join the 'perfSONAR Users' mailing list, please visit:

  https://mail.internet2.edu/wws/info/perfsonar-user

The perfSONAR-PS git repository is located at:

  https://code.google.com/p/perfsonar-ps/

Questions and comments can be directed to the author, or the mailing list.
Bugs, feature requests, and improvements can be directed here:

  http://code.google.com/p/perfsonar-ps/issues/list

=head1 VERSION

$Id: Base.pm 3658 2009-08-28 11:40:19Z aaron $

=head1 AUTHOR

Aaron Brown, aaron@internet2.edu

=head1 LICENSE

You should have received a copy of the Internet2 Intellectual Property Framework
along with this software.  If not, see
<http://www.internet2.edu/membership/ip.html>

=head1 COPYRIGHT

Copyright (c) 2004-2009, Internet2 and the University of Delaware

All rights reserved.

=cut

# vim: expandtab shiftwidth=4 tabstop=4
