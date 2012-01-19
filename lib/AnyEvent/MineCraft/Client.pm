package AnyEvent::MineCraft::Client;

use strict;
use utf8;
use AnyEvent::Socket;
use AnyEvent::Handle;
use Encode;
use Data::Dumper;
sub ping {
    my ($host, $port, $cb) = @_;
    unless($cb) { $cb=$port; $port=25565; }
    tcp_connect($host, $port, sub {
		    my ($fh) = @_;
		    return $cb->(undef, "unable to connect") unless $fh;
		    my $h; $h = new AnyEvent::Handle(
			fh => $fh,
			on_error => sub { AE::log error => "error $_[2]"; $_[0]->destroy; },
			on_eof => sub { $h->destroy; });
		    $h->push_write("\xFE");
		    $h->push_read(AEMCCbyte=> sub {
				      return $h=undef unless $_[1] == 0xFF;
				  });
		    $h->push_read(AEMCCstring => sub {
				      $cb->($_[1]);
				  });
		});
}


sub connect {
    my ($host, $port, $username, $cb) = @_;
    my $loginhash;
    my ($PlayerEntity, $MapSeed, $LevelType, $ServerMode, $Dimenssion, $Difficulty, $WorldHeight, $MaxPlayers);
    tcp_connect($host, $port, sub {
		    my ($fh) = @_;
		    return "unable to connect" unless $fh;
		    my $h; $h = new AnyEvent::Handle(
			fh => $fh,
			on_error => sub { AE::log error => "error $_[2]";  warn $h->{rbuf}; $_[0]->destroy; },
			on_eof => sub { warn $h->{rbuf}; $h->destroy; });
		    $h->push_write(AEMCCbyte => 0x02); #handshake
		    $h->push_write(AEMCCstring => $username);
		    $h->push_read(AEMCCbyte => sub { #handshake answer
				      return if $_[1] == 0x02;
				      die "connection fails got $_[1] instead of 0x02 on handshake";
				  });
		    $h->push_read(AEMCCstring=>sub {
				      $loginhash=$_[1];
				      # seems handshake done
				      $h->push_write(AEMCCbyte => 0x01); #login
				      $h->push_write(AEMCCint => 0x16); #proto
				      $h->push_write(AEMCCstring => $username);
				      $h->push_write(AEMCClong => 0);
				      $h->push_write(AEMCCstring => '');
				      $h->push_write(AEMCCint => 0);
				      $h->push_write(AEMCCbyte => 0);
				      $h->push_write(AEMCCbyte => 0);
				      
				      $h->push_read(AEMCCbyte => sub { #login answer
							return if $_[1] == 0x01;
							die "connection fails got $_[1] instead of 0x01 on login: ".ord($h->{rbuf});
						    });
				      $h->push_read(AEMCCint => sub { $PlayerEntity=$_[1]; });
				      $h->push_read(AEMCCstring => sub { });
				      $h->push_read(AEMCClong => sub { $MapSeed=$_[1]; });
				      $h->push_read(AEMCCstring => sub { $LevelType=$_[1]; });
				      $h->push_read(AEMCCint => sub { $ServerMode=$_[1]; });
				      $h->push_read(AEMCCbyte => sub { $Dimenssion=$_[1]; });
				      $h->push_read(AEMCCbyte => sub { $Difficulty=$_[1]; });
				      $h->push_read(AEMCCbyte => sub { $WorldHeight=$_[1]; });
				      $h->push_read(AEMCCbyte => sub { $MaxPlayers=$_[1]; 
								       warn "($PlayerEntity, $MapSeed, $LevelType, $ServerMode, $Dimenssion, $Difficulty, $WorldHeight, $MaxPlayers)";
								       $cb->();
								   });
				  });
		});
}









### AE handle datatypes
### readers
AnyEvent::Handle::register_read_type AEMCCbyte => sub {
    my ($h, $cb) = @_;
    return sub {
	1 <= length $h->{rbuf} or return;
	$cb->($h, unpack 'c', (substr $h->{rbuf}, 0, 1, ''));
	1;
    }
};

AnyEvent::Handle::register_read_type AEMCCshort => sub {
    my ($h, $cb) = @_;
    return sub {
	2 <= length $h->{rbuf} or return;
	$cb->($h, unpack 's>', (substr $h->{rbuf}, 0, 2, ''));
	1;
    }
};

AnyEvent::Handle::register_read_type AEMCCint => sub {
    my ($h, $cb) = @_;
    return sub {
	4 <= length $h->{rbuf} or return;
	$cb->($h, unpack 'l>', (substr $h->{rbuf}, 0, 4, ''));
	1;
    }
};

AnyEvent::Handle::register_read_type AEMCClong => sub {
    my ($h, $cb) = @_;
    return sub {
	8 <= length $h->{rbuf} or return;
	$cb->($h, unpack 'Q>', (substr $h->{rbuf}, 0, 8, ''));
	1;
    }
};

AnyEvent::Handle::register_read_type AEMCCstring => sub {
    my ($h, $cb) = @_;
    return sub {
	2 <= length $h->{rbuf} or return;
	my $len = 2 * unpack 'S>', (substr $h->{rbuf}, 0, 2); #AEMCCshort characters
	$len + 2 <= length $h->{rbuf} or return;
	substr $h->{rbuf}, 0, 2, '';
	$cb->($h, decode 'UCS-2BE', (substr $h->{rbuf}, 0, $len, ''));
	1;
    }
};

### writers

AnyEvent::Handle::register_write_type AEMCCbyte => sub {
   my ($self, $byte) = @_;
   pack 'C', $byte;
};

AnyEvent::Handle::register_write_type AEMCCshort => sub {
   my ($self, $short) = @_;
   pack 's>', $short;
};

AnyEvent::Handle::register_write_type AEMCCint => sub {
   my ($self, $int) = @_;
   pack 'l>', $int;
};

AnyEvent::Handle::register_write_type AEMCClong => sub {
   my ($self, $long) = @_;
   pack 'q>', $long;
};

AnyEvent::Handle::register_write_type AEMCCstring => sub {
    my ($h, $string) = @_;
    (pack 's>', length $string).encode('UCS-2BE', $string);
};


1;
