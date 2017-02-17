package perfSONAR_PS::MeshConfig::Config::TestParameters::SimpleStream;
use strict;
use warnings;

our $VERSION = 4.0;

use Moose;

=head1 NAME

perfSONAR_PS::MeshConfig::Config::TestParameters::SimpleStream;

=head1 DESCRIPTION

=head1 API

=cut

extends 'perfSONAR_PS::MeshConfig::Config::TestParameters::Base';

override 'type' => sub { "simplestream" };

has 'dawdle'                    => (is => 'rw', isa => 'Int');
has 'fail'                      => (is => 'rw', isa => 'Num');
has 'test_material'             => (is => 'rw', isa => 'Str', default => sub{ "testing123" });
has 'timeout'                   => (is => 'rw', isa => 'Int',);
#probably should be moved out to pscheduler superclass
has 'tool' => (is => 'rw', isa => 'Str');
has 'force_bidirectional'       => (is => 'rw', isa => 'Bool');
has 'random_start_percentage'   => (is => 'rw', isa => 'Int');
has 'slip' => (is => 'rw', isa => 'Int');
has 'slip_randomize' => (is => 'rw', isa => 'Bool');
has 'interval'                  => (is => 'rw', isa => 'Int');
has 'ipv4_only'       => (is => 'rw', isa => 'Bool');
has 'ipv6_only'       => (is => 'rw', isa => 'Bool');

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
