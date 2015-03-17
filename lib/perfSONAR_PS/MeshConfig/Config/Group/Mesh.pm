package perfSONAR_PS::MeshConfig::Config::Group::Mesh;
use strict;
use warnings;

our $VERSION = 3.1;

use Moose;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::Group::Mesh;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::Group';

has 'members'             => (is => 'rw', isa => 'ArrayRef[Str]');
has 'no_agents'           => (is => 'rw', isa => 'ArrayRef[Str]');

sub BUILD {
    my ($self) = @_;
    $self->type("mesh");
}

sub source_destination_pairs {
    my ($self) = @_;

    my %no_agent_map = ();
    if ($self->no_agents) {
        %no_agent_map = map { $_->address => 1 } $self->resolve_addresses($self->no_agents);
    }

    my @pairs = ();
    foreach my $source ($self->resolve_addresses($self->members)) {
        foreach my $destination ($self->resolve_addresses($self->members)) {
            next if $source eq $destination;

            push @pairs, $self->__build_endpoint_pairs({
                                            source_address => $source, source_no_agent => $no_agent_map{$source->address},
                                            destination_address => $destination, destination_no_agent => $no_agent_map{$destination->address},
                                          });
        }
    }

    return \@pairs;
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
