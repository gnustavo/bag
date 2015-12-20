#!/usr/bin/env perl

use 5.010;
use utf8;
use strict;
use autodie;
use warnings;
use open IO => ':locale';
use Encode;
use Encode::Locale;
use Getopt::Long::Descriptive;
use XML::Twig;

Encode::Locale::decode_argv();

my ($opt, $usage) = describe_options(
    '%c %o',
    ['pathsfile=s', "file containing one path per line", {required => 1}],
    ['logfile=s',   "file containing 'svn log --xml -v' output", {required => 1}],
    [],
    ['help',        "print usage message and exit"],
    {show_defaults => 1},
);

if ($opt->help) {
    print $usage->text;
    exit 0;
}

my (%tracking, %holding);

{
    open my $paths, '<', $opt->pathsfile;
    while (<$paths>) {
        chomp;
        $tracking{$_} = undef;
    }
}

# This routine is invoked for each logentry to study its paths and see if we
# can find the creation of one of the paths we are tracking. When we find
# one we print a CSV line, stop tracking the found path and, if it was
# copied from another path, remember the original path and revision (putting
# them "on hold") to start tracking them later on.
sub paths {
    my ($twig, $paths) = @_;

    my $rev = $paths->parent->att('revision');

    # See if we reached a revision in which we must start tracking some
    # other paths.
    if (my $holding = delete $holding{$rev}) {
        foreach my $path (@$holding) {
            $tracking{$path} = undef;
        }
    }

    # Keep track of how many paths we found
    state $found = 0;

    foreach my $path ($paths->descendants('path')) {
        # We only track directories
        next unless $path->att('kind') eq 'dir';

        # Get the path name from the XML tag's text contents
        my $text = $path->text_only;

        # If $text is some path we're tracking and this is where it was
        # created, then we've just found it.
        if (exists $tracking{$text} && $path->att('action') eq 'A') {
            # stop tracking this path
            delete $tracking{$text};
            ++$found;
            if (my $frompath = $path->att('copyfrom-path')) {
                # It was copied from an existing path.
                my $fromrev = $path->att('copyfrom-rev');
                print '"', join('","', $text, $rev, $frompath, $fromrev), "\"\n";
                # Remember from where it was copied to start tracking its
                # original path when we reach $fromrev.
                push @{$holding{$fromrev}}, $frompath;
            } else {
                # It was created from scratch
                print '"', join('","', $text, $rev, '', ''), "\"\n";
            }
            warn
                "$rev ",
                "tracking(", scalar(keys(%tracking)), ") ",
                "holding(",  scalar(keys(%holding)),  ") ",
                "found($found)\n";

            # Exit if there's nothing else to do
            exit 0 unless keys %tracking || keys %holding;
        }
    }

    # Purge whatever we've already processed to avoid wasting memory
    $twig->purge;
    return 1;
}

my $twig = XML::Twig->new(
    twig_handlers => {
        paths => \&paths,
    },
);

$| = 1;                         # flush on every print

$twig->parsefile($opt->logfile);

if (keys %tracking) {
    warn "WARN: finished with ", scalar(keys(%tracking)), " paths on \%tracking:\n";
    foreach (sort keys %tracking) {
        warn "  $_\n";
    }
}

if (keys %holding) {
    warn "WARN: finished with ", scalar(keys(%holding)), " paths on \%holding:\n";
    foreach (sort keys %holding) {
        warn "  $_\n";
    }
}


__END__
=encoding utf8

=head1 NAME

svn-trace-paths.pl - Trace branches/tags history in Subversion log

=head1 SYNOPSIS

    svn-trace-paths.pl [long options...]
	--pathsfile STR   file containing one path per line
	--logfile STR     file containing 'svn log --xml -v' output
	--help            print usage message and exit

=head1 DESCRIPTION

The script produces a CSV spreadsheet on its standard output, so it's better
to redirect it to a file. Each line represents the creation of a path. The
first column has the path and the second column the numeric revision when it
was created. If it was created as a copy from another path (which is the
most common situation if you're following branches and tags) it has two more
columns showing the name of the original path and the revision from which is
was copied. A fictional example may make it clearer:

  /tags/1.0.1       1534 /branches/fix/1.0 1533
  /tags/1.0.0       1234 /branches/fix/1.0 1230
  /branches/fix/1.0  999 /trunk             998
  /trunk               1

In this example you could have passed in --pathsfile only the two paths for
the tags (/tags/1.0.1 and /tags/1.0.0). The script would start out tracking
them and would find along the way from which paths they were copied, at
which point it would start tracking those. That's why it ended up showing
the history of /branches/fix/1.0 and /trunk.

Note that since /trunk wasn't copied from anywhere, it's line shows just the
two first columns.

Also note that /tags/1.0.0 was created on r1234 as a copy from
/branches/fix/1.0, but from a previous revision: r1230. This is common in
some situations. If you use an automated continuous integration system to
validate your branch and tag them automatically it can take several minutes
to validate it while new commits may be created so that at the end the tag
must be made to the revision that was validated, which isn't HEAD anymore.

=head1 OPTIONS

The two options are actually required.

=over

=item * B<--pathsfile FILE>

The --pathsfile argument must be a file listing one path per line. Each path
represents a branch, a tag, or trunk, i.e., everything you want to trace the
history of.

=item * B<--logfile FILE>

the --logfile argument must be a file containing the complete log of the
repository in XML format, which you may produce like this:

=back

=head1 COPYRIGHT

Copyright 2015 CPqD.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Gustavo Chaves <gustavo@cpqd.com.br>
