#!/usr/bin/env perl
## raw_ids.pl: Copyright (C) 2022 Harald Hope
## 
## License: GNU GPL v3 or greater
##
## You should have received a copy of the GNU General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.
##
## If you don't understand what Free Software is, please read (or reread)
## this page: http://www.gnu.org/philosophy/free-sw.html
##
## These are based on lists found on latest driver support page:
## https://www.nvidia.com/Download/driverResults.aspx/187826/en-us
## http://us.download.nvidia.com/XFree86/Linux-x86_64/515.43.04/README/supportedchips.html#subsys
## Copy with mouse highlight the driver section, then paste that into a text file.
## Make sure it preserves the tabs \t!!! Otherwise it won't work!
use strict;
use warnings;
# use diagnostics;
use 5.024;

use Data::Dumper qw(Dumper); 
$Data::Dumper::Sortkeys = 1;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure ('bundling', 'no_ignore_case', 
'no_getopt_compat', 'no_auto_abbrev','pass_through');

my $self_name = 'raw_ids.pl';
my $self_version = '1.0';
my $self_date = '2022-05-21';

my $job = 'amd'; # default
my $options = 'amd|intel'; # expand with |.. if > 1 job used in future
my ($active,$data,$devices,$devices_sub);
my ($b_print_devices,$b_use_sub_pci);
my $line = '------------------------------------------------------------------';

my $jobs = {
'amd' => {
'filters' => 'SMBus|^SB|^RC|IOMMU|host control|TV|Decoder|Theater|Bridge|Serial ATA|SATA|USB|IDE Con|Audio|Modem|Xilleon',
'file-output' => 'lists/gpu.amd.full',
'file-output-sorted' => 'lists/gpu.amd.full.sort',
'files' => [
# source: check for updated file!: http://pci-ids.ucw.cz/v2.2/pci.ids
{
'file' => 'lists/pci.ids.v2.2.ucw.cz',
'id-name' => '\t(\S{4})\s+(.+)',
'id-name-sub' => '\t\t1002\s+(\S{4})\s+(.+)',
'last' => '1003',
'next' => '^\s*#',
'start' => '1002',
},
# source: https://devicehunt.com/search/type/pci/vendor/1002/device/any
{
'file' => 'lists/amd.raw.ids.dh.com',
'id-name' => '[^\t]+\t+1002[^\t]+\t+(\S{4})\t+(.+)',
},
],
},
'intel' => {
#'filters' => '^\t\t|Aggregat|AUDIO|Bridge|\bbus\b|Centrino|Caching|Channel|Chipset|DMA|DMI\b|DRAM|Driver|Ethernet|GPIO|HECI|Host Controller|\bHUb\b|IDE|Interleave|I2C|I\/O|ISA|Keyboard|LPC|Management|MEI|Memory|Network|Parallel|PCH|PCI Express|PCIe C|\bPort\b|Power|QAT|RAID|Register|SATA|Scalab|SMBus|Sensor|Serial|SPI|SRAM|Thermal|Tuning|UART|USB|Wireless',
'filters' => '^\t\t',
#'filters' => '^.*((?!Graphic)).)*',
'file-output' => 'lists/gpu.intel.full',
'file-output-sorted' => 'lists/gpu.intel.full.sort',
'files' => [
{
'file' => 'lists/pci.ids.v2.2.ucw.cz',
'id-name' => '\t(\S{4})\s+(.+)',
'id-name-sub' => '',
'last' => '8088',
'next' => '^\s*#',
'start' => '8086',
'unless' => 'Graphic',
},
# source: https://devicehunt.com/search/type/pci/vendor/1002/device/any
{
'file' => 'lists/intel.raw.ids.dh.com',
'id-name' => '[^\t]+\t+1002[^\t]+\t+(\S{4})\t+(.+)',
'unless' => 'Graphic',
},
],
},
'nv' => {
'filters' => '',
'file-output' => '',
'file-output-sorted' => '',
'files' => [
{
'file' => '',
'filters' => '',
}
]
},
};

sub process {
	say "Starting processing of $job item.";
	foreach my $info (@{$active->{'files'}}){
		say $line;
		say "Processing $info->{'file'}...";
		die "$info->{'file'} is not readable!!" if ! -r $info->{'file'};
		build($info);
	}
	say $line;
	say "All done with processing. Continuing to output stage.";
}
sub build {
	my ($info) = @_;
	say "Building data...";
	reader($info->{'file'});
	my $b_vendor;
	my $start = $info->{'start'};
	$b_vendor = 1 if !$start;
	my $last = ($info->{'last'}) ? $info->{'last'} : undef;
	my $next = ($info->{'next'}) ? $info->{'next'} : undef;
	my $pci = $info->{'id-name'};
	my $sub_pci = ($info->{'id-name-sub'}) ? $info->{'id-name-sub'} : undef;
	my $filters = $active->{'filters'};
	my $unless = ($info->{'unless'}) ? $info->{'unless'} : undef;
	foreach my $row (@$data){
		next if $next && $row =~ /$next/;
		last if $last && $row =~ /^$last/;
		$b_vendor = 1 if !$b_vendor && $row =~ /^$start/;
		if ($b_vendor){
			next if $row =~ /$filters/i;
			next if $unless && $row !~ /$unless/i;
			if ($row =~ /^$pci$/){
				push(@$devices,[lc($1),$2]);
			}
			elsif ($sub_pci && $row =~ /^$sub_pci$/){
				push(@$devices_sub,[lc($1),$2]);
			}
			# say $row;
		}
		
	}
	if ($devices){
		@$devices = sort { $a->[0] cmp $b->[0] } @$devices;
	}
	else {
		die "\$devices is empty!";
	}
	if ($devices_sub){
		@$devices_sub = sort { $a->[0] cmp $b->[0] } @$devices_sub;
	}
	if ($b_print_devices){
		say "$line\nDevices:\n", Dumper $devices;
		say "$line\nSub Devices:\n", Dumper $devices_sub if $devices_sub ;
		say $line;
	}
	say "Done building data for $info->{'file'}.";
}
sub output {
	say $line;
	say "Creating PCI ID sorted output...";
	my $output;
	foreach my $item (@$devices){
		push(@$output,"$item->[1]\t$item->[0]");
	}
	uniq($output);
	writer($active->{'file-output'},$output);
	$output = undef;
	say "Creating device name sorted output...";
	@$devices = sort { $a->[1] cmp $b->[1] } @$devices;
	foreach my $item (@$devices){
		push(@$output,"$item->[1]\t$item->[0]");
	}
	uniq($output);
	writer($active->{'file-output-sorted'},$output);
	say "Finished creating output";
	
}

sub assign {
	$active = $jobs->{$job};
	# say Dumper $active;
}

sub checks {
	my @errors;
	if (! -e $self_name ){
		push(@errors,"You must start $self_name from the directory it is located in!");
	}
	if (@errors){
		print "The following errors were encountered:\n* ";
		say join("* ", @errors);
		exit 1;
	}
}

sub reader {
	my $file = $_[0];
	if (!$file || ! -r $file){
		die "$file does not exist, or is not readable!";
	}
	open(my $fh, '<', $file) or die "Reading $file failed with error: $!";
	chomp(@$data = <$fh>);
	close $fh;
	die "\@data had no data!" if !@$data;
}
sub uniq {
	my %seen;
	@{$_[0]} = grep !$seen{$_}++, @{$_[0]};
}
# arg: 1 file full  path to write to; 2 - array ref or scalar of data to write. 
# note: turning off strict refs so we can pass it a scalar or an array reference.
sub writer {
	my ($path, $content) = @_;
	my ($contents);
	no strict 'refs';
	# print Dumper $content, "\n";
	if (ref $content eq 'ARRAY'){
		$contents = join("\n", @$content); # or die "failed with error $!";
	}
	else {
		$contents = $content;
	}
	open(my $fh, ">", $path) or die "Writing $path failed with error: $!";
	print $fh $contents;
	close $fh;
}

sub options {
	my @errors;
	Getopt::Long::GetOptions (
	'd|devices' => sub {
		$b_print_devices = 1;
	},
	'h|help' => sub {
		show_options();
		exit 0;
	},
	'j|job:s' => sub {
		my ($opt,$arg) = @_;
		if ($arg =~ /^($options)$/){
			$job = $arg;
		}
		else {
			push(@errors,"Unsupported option for -$opt: $arg\n  Use [$options]");
		}
	},
	's|subs' => sub {
		$b_use_sub_pci = 1;
	},
	'v|version' => sub {
		show_version();
		exit 0;
	},
	'<>' => sub {
		my ($opt,$arg) = @_;
		push(@errors,"Unsupported option $opt");
	},
	);
	if (@errors){
		print "Sorry, Options Error:\n* ";
		say join("\n* ",@errors);
		say $line;
		show_options();
		exit 1;
	}
}
sub show_options {
	show_version();
	say "\nAvailable Options:";
	say "-d,--devices  - print raw devices output.";
	say "-j,--job      - Job to run: [$options]";
	say "-h,--help     - This help option menu";
	say "-s,--sub      - Use the sub PCI devices. Careful with this!";
	say "-v,--version  - Show tool version and date.";
}
sub show_version {
	say "$self_name v: $self_version date: $self_date";
}
sub main {
	checks();
	options();
	assign();
	process();
	output() if $devices;
}
main();