#!/usr/bin/perl -w

### gdrive-status.pl
### Script to get a "git status" of your Google Drive folder.
###
### Author: Nathan Campos <nathan@innoveworkshop.com>

use strict;
use warnings;

use DateTime;
use DateTime::Format::ISO8601;
use Term::ANSIColor;

# Parses a output line.
sub parse_line {
	my ($arr, $line, $unknowns) = @_;
	my %file = (
		status => "unknown",
		newer => "unknown",
		loc => ""
	);

	# Detect what kind of status the file is currently in.
	if ($line =~ /(.+)( only on remote)$/g) {
		# New cloud file.
		$file{"status"} = "new";
		$file{"newer"} = "remote";
		$file{"loc"} = $1;
	} elsif ($line =~ /(.+)( only on local)$/g) {
		# New local file.
		$file{"status"} = "new";
		$file{"newer"} = "local";
		$file{"loc"} = $1;
	} else {
		# Can't decode or is a modification.
		$$unknowns .= "$line\n";
		return;
	}

	# Push file to the array.
	push @$arr, \%file;
}

# Parses a modified file.
sub parse_modified {
	my ($arr, $output) = @_;
	
	# Don't ask...
	while ($output =~ /File: (.+)\n\* (.+):\s+(.+[^\s])\s*\n\* (.+):\s+(.+[^\s])\s*\n.+\n\*{4}/g) {
		my %file = (
			status => "modified",
			newer => "unknown",
			loc => $1
		);

		my %dt = (
			"$2" => DateTime::Format::ISO8601->parse_datetime($3),
			"$4" => DateTime::Format::ISO8601->parse_datetime($5)
		);

		if ($dt{"remote"} > $dt{"local"}) {
			$file{"newer"} = "remote";
		} else {
			$file{"newer"} = "local";
		}

		push @$arr, \%file;
	}
}

# Prints the list of files for a given status.
sub print_status {
	my ($status, $files_arr) = @_;
	my @files = @{ $files_arr };

	foreach my $file_hash (@files) {
		my %file = %{ $file_hash };

		# Check if the file status is the one we are looking for.
		if ($file{"status"} eq $status) {
			if ($status eq "new") {
				if ($file{"newer"} eq "remote") {
					print colored("new file (remote): ", "red") . 
						"$file{'loc'}\n";
				} else {
					print colored("new file (local): ", "green") . 
						"$file{'loc'}\n";
				}
			} elsif ($status eq "modified") {
				print colored("modified ($file{'newer'}): ", "blue") .
					"$file{'loc'}\n";
			}
		}
	}
}

# Main function.
sub main {
	my ($path) = @_;
	my @files;
	my $rest = "";

	print "Fetching data... ";
	my $output = `drive diff -skip-content-check -base-local=true -depth=-1 "$path" 2>&1`;
	print "done.\n";

	# Loop through each line.
	foreach my $line (split /[\r\n]+/, $output) {
		parse_line(\@files, $line, \$rest);
	}

	# Parse the modified files.
	parse_modified(\@files, $rest);

	# Print each file status.
	print_status("new", \@files);
	print_status("modified", \@files);

	# Check if there was an error.
	if (scalar(@files) == 0) {
		print colored("Looks like something went wrong. ", "red") . "Here's the command output:\n$output";
	}
}

if (scalar(@ARGV) == 1) {
	main(@ARGV);
} else {
	print "Please provide a path.\n";
}

