#!/usr/bin/env perl
use warnings;
use strict;
use LWP::Simple;
use Date::Manip;
use Digest::MD5 qw(md5_base64);

my $path="https://256.makerslocal.org/wiki";
my $filename="/var/www/256/calendar.ics";
my $name="Makers Local 256";
#############
$path =~ /^(https?:\/\/.*?)\//;
my $site=$1;

open (ICS, ">$filename.new");
print ICS <<EOL;
BEGIN:VCALENDAR
PRODID:-//myown//EN
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
X-WR-CALNAME:$name
X-WR-TIMEZONE:America/Chicago
BEGIN:VTIMEZONE
TZID:America/Chicago
X-LIC-LOCATION:America/Chicago
BEGIN:DAYLIGHT
TZOFFSETFROM:-0600
TZOFFSETTO:-0500
TZNAME:CDT
DTSTART:19700308T020000
RRULE:FREQ=YEARLY;BYMONTH=3;BYDAY=2SU
END:DAYLIGHT
BEGIN:STANDARD
TZOFFSETFROM:-0500
TZOFFSETTO:-0600
TZNAME:CST
DTSTART:19701101T020000
RRULE:FREQ=YEARLY;BYMONTH=11;BYDAY=1SU
END:STANDARD
END:VTIMEZONE
EOL

sub build_vevent {
	# get arguments
	my %args = %{$_[0]};
	my $line = $args{'line'};
	my $title = $args{'title'};
	my $shorturl = $args{'url'};
	# copy title to temp variable and convert any special characters to normal characters
	my $title2 = $title;
	$title2 =~ s/_/ /g;
	# strip unordered list wiki formatting
	$line =~ s/^\* ?//;
	# setup regex match
	$line =~ /^(.*) *: +(.*?)( at (.*))?$/i;
	return unless ($1);
	# split out start and end times, if applicable
	my @eventtime = split(/ *- */, $1);
	# get our actual event title
	my $eventtitle = $2;
	# our location defaults to nothing if it's not set
	my $location = "";
	$location = $4 if ($4);
	print "$eventtitle - $line\n" if ($ARGV[0]);
	#print "eventtime[0]: $eventtime[0]\n" if ($ARGV[0]);
	# Figure out our start time in unix epoch
	my $datetime1=UnixDate(ParseDateString($eventtime[0]), '%Y%m%dT%H%M%S');
	my $starttime = $datetime1;
	if  (!$datetime1) {
		#print "Error parsing $eventtime[0] from $title\n";
		return;
	}
	# figure out our end time, if we have one
	my $endtime;
	my $toreturn = "BEGIN:VEVENT\n";
	if ($eventtime[1]) {
		print "-"x20 . "\nDetected duration element\n" if ($ARGV[0]);
		print "eventtime[1]: -$eventtime[1]-\n" if ($ARGV[0]);
		if ($eventtime[1] =~ /^ *\d{1,2}(:\d{1,2})?([apm]){0,2} *$/i) {
			print "Detected time element\n" if ($ARGV[0]);
			my $step = UnixDate(ParseDateString($eventtime[0]), "%m/%d/%Y") . " $eventtime[1]";
			$step = UnixDate(ParseDateString($step), '%Y%m%dT%H%M%S');
			$endtime = $step;
			$toreturn .= "DTSTART:$starttime\n";
			$toreturn .= "DTEND:$endtime\n";
		}
		else {
			$endtime = UnixDate(ParseDateString($eventtime[1]), '%Y%m%dT%H%M%S');
			$endtime =~ s/T000000$//;
			$starttime =~ s/T000000$//;
			$toreturn .= "DTSTART;VALUE=DATE:$starttime\n";
			$toreturn .= "DTEND;VALUE=DATE:$endtime\n";
		}
	}
	else {
		if ($starttime =~ /T000000$/) {
			$starttime = substr($datetime1, 0, 8);
			$endtime = substr(UnixDate(DateCalc(ParseDateString($eventtime[0]), "+ 1 day"), '%Y%m%dT%H%M%S'), 0, 8);
			$toreturn .= "DTSTART;VALUE=DATE:$starttime\n";
			$toreturn .= "DTEND;VALUE=DATE:$endtime\n";
		}
		else {
			$endtime = UnixDate(DateCalc(ParseDateString($eventtime[0]), "+ 1 hour"), '%Y%m%dT%H%M%S');
			$toreturn .= "DTSTART:$starttime\n";
			$toreturn .= "DTEND:$endtime\n";
		}
	}

	$toreturn .= "UID:" . md5_base64($line) . "\n";
	$toreturn .= "SUMMARY:$eventtitle\n";
	$toreturn .= "LOCATION:$location\n" if ($location);
	$toreturn .= "URL:$shorturl\n";
	$toreturn .= "DESCRIPTION:$shorturl\n";
	$toreturn .= "END:VEVENT\n";
	#return {DTSTART => $starttime, DTEND => $endtime};
}


#my @tests = (
#		{line => "Jan 13: Meeting", DTSTART => '20090113', DTEND => '20090114'},
#		{line => "Jan 13th 7pm: Meeting", DTSTART => '20090113T190000', DTEND => '20090113T200000'},
#		{line => "Jan 13 19:00: Meeting", DTSTART => '20090113T190000', DTEND => '20090113T200000'},
#		{line => "January 13 19:00 - 9pm: Meeting", DTSTART => '20090113T190000', DTEND => '20090113T210000'},
#		{line => "Jan 13 7pm - 8:30pm: Meeting", DTSTART => '20090113T190000', DTEND => '20090113T203000'},
#		{line => "Jan 13th - Jan 15th: Meeting", DTSTART => '20090113', DTEND => '20090115'},
#		{line => "Jan 13th - Feb 2nd: Meeting", DTSTART => '20090113', DTEND => '20090202'},
#		{line => "Jan 13th 6pm - Feb 14th 2pm: Meeting", DTSTART => '20090113T180000', DTEND => '20090214T140000'}
#	);
#my $x=1;
#foreach my $test (@tests) {
#	print "-"x40 . "\nTest $x\n";
#	my $returned = build_vevent({title => "Test", line => $test->{'line'}});
#	if (	$returned->{'DTSTART'} eq $test->{'DTSTART'} and
#		$returned->{'DTEND'} eq $test->{'DTEND'}) {
#		print "PASSED\n";
#	}
#	else {
#		print "FAILED\n";
#		print Dumper($returned);
#		print Dumper($test);
#	}
#	$x++;
#}
#
#exit;

sleep 2;
#my $page=get("$path/index.php?title=Special%3ASearch&ns0=1&ns2=1&search=Calendar&fulltext=Advanced+search&limit=500");
my $page=get("$path/index.php?title=Special%3Search&limit=500&offset=0&redirs=0&ns0=1&ns2=1&search=Calendar");
$page =~ s/\n//g;

my @pages_to_check = ();
while($page =~ /href *= *"?(.*?)[" >]/g){
	my $match = $1;
	if ($match =~ /^\/wiki\//) {
		#last if ($match =~ /^http/);
		next if ($match =~ /(=|\/)Special/);
		next if ($match =~ /(=|\/)Section42/);
		next if ($match =~ /(=|\/)Help/);
		next if ($match =~ /index.php/);
		$match =~ s/#.*$//;
		push @pages_to_check, $match unless grep { $_ eq $match } @pages_to_check;
	}
}
print "Checking unique pages\n" if ($ARGV[0]);
foreach my $match (@pages_to_check) {
	print "Match $match\n" if ($ARGV[0]);
	$match =~ s/wiki\//wiki\/index.php?title=/;
	$match =~ /title=(.*)$/;
	my $title=$1;
	next if ($title eq "Event");
	#$title =~ s/^.*\///;
	print "Getting $site$match&action=raw\n" if ($ARGV[0]);
        print STDERR "$site$match\n";
	my $pagedata=get("$site$match&action=raw");
	next unless $pagedata;
	my $shorturl;
	my $flag=0;
	#print "$match\n";
	if ($pagedata =~ /<title>Error<\/title>/) {
		print "There was an error while trying to get $site$match\n";
		next;
	}	
	foreach my $line (split(/\n/, $pagedata)) {
		#print "checking: $line\n" if ($ARGV[0]);
		if ($flag == 0 && $line =~ /^==? *Calendar *==?/) {
			print "turning flag on\n" if ($ARGV[0]);
			$flag = 1;
			$shorturl = get($site . $match);
			$shorturl =~ /(http:\/\/ml256.org.[^"]*)"/;
			$shorturl = $1;
		}
		elsif ($flag == 1 && $line =~ /^\*[^\*]/) {
			print "line: $line\n" if ($ARGV[0]);
			#$line =~ s/^\*+ *//g;
			print ICS build_vevent({title => $title, line => $line, url => $shorturl});
		}
		elsif ($flag == 1 && $line =~ /^==?[^=]/) {
			print "turning flag off\n" if ($ARGV[0]);
			$flag = 0;
			last;
		}
	}
	sleep 2;
}

print ICS "END:VCALENDAR\n";
rename "$filename.new", $filename;
