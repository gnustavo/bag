#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use autodie;
use warnings;
use File::Find;
use File::Spec::Functions qw/rel2abs/;
use Getopt::Long;

my $usage   = "$0 [--dont] [--verbose] [--script=SCRIPT] [--hooks=HOOK,...] [REPOSDIR]\n";
my $Dont    = 0;
my $Verbose = 0;
my $Script  = "$ENV{HOME}/bin/githooks.pl";
my $Hooks   = 'pre-receive';
GetOptions(
    dont       => \$Dont,
    'verbose+' => \$Verbose,
    'script=s' => \$Script,
    'hooks=s'  => \$Hooks,
) or die $usage;

-x $Script or die "The script '$Script' isn't an executable file.\n";
$Script = rel2abs($Script);

$Hooks =~ /[^a-z,-]/ and die "Invalid hook name in '$Hooks'.\n";
my @hooks = split ',', $Hooks;

my $reposdir = shift || "$ENV{HOME}/repos";
-d $reposdir or die "No such directory: $reposdir\n";

sub wanted {
    if (-d $_ && -d "$_/hooks") {
	$File::Find::prune = 1;
	my $H = "$_/hooks";
	foreach my $hook (@hooks) {
	    if (! -e "$H/$hook") {
		warn "$H/$hook -> $Script\n" if $Verbose;
		symlink $Script, "$H/$hook" unless $Dont;
	    } elsif (! -l "$H/$hook") {
		warn "$H/$hook isn't a symlink.\n";
	    } elsif (readlink("$H/$hook") ne $Script) {
		warn "$H/$hook links to '", readlink("$H/$hook"), "', not to '$Script'.\n";
	    } else {
		warn "$H/$hook is uptodate.\n" if $Verbose;
	    }
	}
    }
}

find({wanted => \&wanted, no_chdir => 1}, $reposdir);


__END__
=head1 NAME

rc-setup-githooks.pl - Set up Git::Hooks for every RhodeCode repository.

=head1 SYNOPSIS

rc-setup-githooks.pl [--dont] [--verbose] [--script=SCRIPT] [--hooks=HOOK,...] [REPOSDIR]

=head1 DESCRIPTION

This script sets up symlinks for specific hooks in the Git
repositories of a RhodeCode instance, pointing them to a script for
Git::Hooks. You should run it after creating (or cloning) new
repositories in RhodeCode in order to garantee that every Git
repository is correctly setup with regards to its hooks.

The script also checks that every existing hook is correctly
configured and warns the user otherwise.

=head1 OPTIONS

=over

=item --dont

Don't actually install the symlinks.

=item --verbose

Tells about every symlink installed and every symlink already uptodate.

=item --script=SCRIPT

This option specifies which script should the hooks point to. It has a
default value which is configured in the $Script variable at the
beginning of the script.

=item --hooks=HOOK,...

This option specifies which hooks should have symlinks installed. Git
implements 16 different hooks but you normally are interested only in
a few. By default, only the 'pre-receive' hook is installed. This
default is configured in the $Hooks variable at the beginning of the
script.

=back

=head1 SEE ALSO

L<http://rhodecode.org>, L<https://metacpan.org/module/Git::Hooks>.

=head1 COPYRIGHT

Copyright 2012 CPqD.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Gustavo Chaves <gustavo@cpqd.com.br>
