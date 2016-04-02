package main;
use strict;
use warnings;
use IO::Socket::INET;
use JSON;

my %NEOHUB_sets = (
	"mintemp" => "TextField",
	"maxtemp" => "TextField",
	"settemp" => "TextField"
);

sub NEOHUB_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}      = 'NEOHUB_Define';
    $hash->{UndefFn}    = 'NEOHUB_Undef';
    $hash->{SetFn}      = 'NEOHUB_Set';
    $hash->{GetFn}      = 'NEOHUB_Get';
    $hash->{GetUpdate}  = 'NEOHUB_GetUpdate';
    $hash->{AttrFn}     = 'NEOHUB_Attr';
    $hash->{ReadFn}     = 'NEOHUB_Read';
    $hash->{AttrList} = 'none';
}
sub NEOHUB_Define($$) {
    my ($hash, $def) = @_;
    my @param = split('[ \t][ \t]*', $def);
    
    if(int(@param) < 4) {
        return "too few parameters: define <name> NEOHUB <ip> <interval>";
    }
    $hash->{name}  = $param[0];
    $hash->{IP} = $param[2];
    $hash->{INTERVAL} = $param[3];
    RemoveInternalTimer($hash);
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "NEOHUB_GetUpdate", $hash, 0); 
    NEOHUB_Get($hash,$hash->{NAME},"status"); 
    return undef;
}


sub NEOHUB_GetUpdate($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    InternalTimer(gettimeofday()+$hash->{INTERVAL}, "NEOHUB_GetUpdate", $hash, 1) if ($hash->{INTERVAL});
    Log3 $name, 5, "NEOHUB: GetUpdate";
    NEOHUB_Get($hash,$name,"status") if ($hash->{INTERVAL});
    return undef;
}


sub NEOHUB_Undef($$) {
    my ($hash, $arg) = @_; 
    # nothing to do
    RemoveInternalTimer($hash);
    return undef;
}

sub NEOHUB_Get($@) {
	my ($hash, @param) = @_;
	my $name = shift @param;
	my $room = shift @param;
	Log3 $name, 5, "NEOHUB: ".$hash->{IP};
	my $neohubsocket = IO::Socket::INET->new(
    	PeerAddr => $hash->{IP},
    	PeerPort => 4242,
    	Proto => 'Tcp',
        blocking    => 0,
        Timeout  => 2
	);
	my $info=qq("INFO");
	my $req = '{'.$info.':0}'.chr(0);
	Log3 $name, 5, "NEOHUB: Get: Open Socket now";
	my $size=$neohubsocket->send($req);
  	my $buffer;
	my $i=1; 
        Log3 $name, 5, "NEOHUB: Get: Do while loop for all Neohub devices";
	while(1)
	{
		my $char;
		$i++;
		$neohubsocket->recv($char,3);
   		$buffer .= $char; 
		Log3 $name, 5, "NEOHUB:".$char;
		if(index($buffer,"]}") ne "-1")
		{
			Log3 $name, 5, "NEOHUB: Get: Update last value";
			last;
		}
	}
	Log3 $name, 5, "NEOHUB: Get: All data retrieved";
	my $decoded;
	$decoded = decode_json($buffer);
	my @info = @{ $decoded->{'devices'} };
	Log3 $name, 5, "NEOHUB: Get: Now starting to update readings";
	foreach my $thermostat ( @info ) {
        	readingsBeginUpdate($hash);
		my $readingName1 = $thermostat->{"device"} . "_temp";
		my $readingName2 = $thermostat->{"device"} . "_heating";
		my $readingName3 = $thermostat->{"device"} . "_settemp";
                my $wert1 = $thermostat->{"CURRENT_TEMPERATURE"};
                my $wert2 = $thermostat->{"HEATING"};
		my $wert3 = $thermostat->{"CURRENT_SET_TEMPERATURE"};
        	readingsBulkUpdate($hash, $readingName1, $wert1 );
		readingsBulkUpdate($hash, $readingName2, $wert2 );
		readingsBulkUpdate($hash, $readingName3, $wert3 );
        	readingsEndUpdate($hash, 1);
	}
	close $neohubsocket;
	return undef;
}

sub NEOHUB_Set($@) {
	my ($hash, @param) = @_;
	
	return '"set NEOHUB" needs at least two arguments <devicename> <value>' if (int(@param) < 2);
	
	my $name = shift @param;
	my $device = shift @param;
	my $set = shift(@param);
	my $value = shift(@param); 
        Log 5, "NEOHUB: Set:".$name. " - ".$device." - ".$set." - ".$value;
	return undef;
}


sub NEOHUB_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	if($cmd eq "set") {
        if($attr_name eq "formal") {
			if($attr_value !~ /^yes|no$/) {
			    my $err = "Invalid argument $attr_value to $attr_name. Must be yes or no.";
			    Log 3, "NEOHUB: ".$err;
			    return $err;
			}
		} else {
		    return "Unknown attr $attr_name";
		}
	}
	return undef;
}

1;

=pod
=begin html

<a name="NEOHUB"></a>
<h3>NEOHUB</h3>
<ul>
    <i>NEOHUB</i> implements the control of Heatmiser Neohub Thermostats. 
    <br><br>
    <a name="NEOHUBdefine"></a>
    <b>Define</b>
    <ul>
        <code>define <name> NEOHUB <ip> <interval></code>
        <br><br>
        Example: <code>define NEOHUB MyHub 192.168.1.5 5</code>
        <br><br>
        The "IP" parameter is the IP address of the Neohub box.<br>
        The "interval" parameter defines the interval of updates requested from the Neohub<br>
    </ul>
    <br>
    
    <a name="NEOHUBset"></a>
    <b>Set</b><br>
    <ul>
        <code>set <name> <option> <value></code>
        <br><br>
        You can <i>set</i> any value to any of the following options. They're just there to 
        <i>get</i> them. See <a href="http://fhem.de/commandref.html#set">commandref#set</a> 
        for more info about the set command.
        <br><br>
        Options:
        <ul>
              <li><i>satisfaction</i><br>
                  Defaults to "no"</li>
              <li><i>whatyouwant</i><br>
                  Defaults to "can't"</li>
              <li><i>whatyouneed</i><br>
                  Defaults to "try sometimes"</li>
        </ul>
    </ul>
    <br>

    <a name="Helloget"></a>
    <b>Get</b><br>
    <ul>
        <code>get <name> <option></code>
        <br><br>
        You can <i>get</i> the value of any of the options described in 
        <a href="#Helloset">paragraph "Set" above</a>. See 
        <a href="http://fhem.de/commandref.html#get">commandref#get</a> for more info about 
        the get command.
    </ul>
    <br>
    
    <a name="Helloattr"></a>
    <b>Attributes</b>
    <ul>
        <code>attr <name> <attribute> <value></code>
        <br><br>
        See <a href="http://fhem.de/commandref.html#attr">commandref#attr</a> for more info about 
        the attr command.
        <br><br>
        Attributes:
        <ul>
            <li><i>formal</i> no|yes<br>
                When you set formal to "yes", all output of <i>get</i> will be in a
                more formal language. Default is "no".
            </li>
        </ul>
    </ul>
</ul>

=end html

=cut
