package perfSONAR_PS::MeshConfig::Config::Site;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;
use Params::Validate qw(:all);

use perfSONAR_PS::MeshConfig::Config::Location;
use perfSONAR_PS::MeshConfig::Config::Administrator;
use perfSONAR_PS::MeshConfig::Config::Host;
use perfSONAR_PS::MeshConfig::Config::MeasurementArchive;
use perfSONAR_PS::MeshConfig::Config::Organization;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::Site;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Base';

has 'description'          => (is => 'rw', isa => 'Str');

has 'location'             => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Location');

has 'administrators'       => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Administrator]', default => sub { [] });
has 'hosts'                => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::Host]', default => sub { [] });
has 'measurement_archives' => (is => 'rw', isa => 'ArrayRef[perfSONAR_PS::MeshConfig::Config::MeasurementArchive]', default => sub { [] });

has 'tags'                => (is => 'rw', isa => 'ArrayRef[Str]', default => sub { [] });

has 'parent'               => (is => 'rw', isa => 'perfSONAR_PS::MeshConfig::Config::Organization');

sub lookup_administrators {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { recursive => 1 } );
    my $recursive  = $parameters->{recursive};

    if (scalar(@{ $self->administrators }) > 0) { # i.e. if there is actually a set of administrators
        return $self->administrators;
    }
    elsif ($recursive) {
        return $self->parent->lookup_administrators({ recursive => $recursive });
    }
    else {
        return;
    }
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

    return $self->parent->lookup_measurement_archive({ type => $type });
}

sub lookup_measurement_archives {
    my ($self, @args) = @_;
    my $parameters = validate( @args, { type => 1, recursive => 1 } );
    my $type       = $parameters->{type};
    my $recursive  = $parameters->{recursive};
    
    my @measurement_archives = ();
    foreach my $measurement_archive (@{ $self->measurement_archives }) {
        if ($measurement_archive->type eq $type) {
            push @measurement_archives, $measurement_archive;
        }
    }

    if ($recursive and $self->parent) {
        push @measurement_archives, @{$self->parent->lookup_measurement_archives({ type => $type, recursive => 1 })};
    }
    
    return \@measurement_archives;
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
