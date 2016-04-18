package CCS::Phantom;

#
# Date:        10.12.2014
# Author:      Zaplatin ICHI Lev (dev@ichi.su)
# Description: Пакет для разбора NWU и NTF-файлов на составляющие
# Version:     1.0.0
# 

use CCS::Utils;
use DateTime;
use bigint;

sub new{
	my $class = shift;
	my $file = shift;
	my $self = {
		version => '1.0.1',             # версия пакета
		_buffer => undef,               # файл
		_time_offset => '-11644473600', # разница между MS timestampt(начало 01.01.1601) и Unix timestampt(начало 01.01.1970)
		_file_length => 1883,           # смещение для NTF-файлов
		_file_offset_ntf => 0,          # смещение для NTF-файлов
		_file_offset_nwu => 40,         # смещения для NWU-файлов
		_file_type => undef,            # тип файла nwu/ntf
		file => $file,                  # имя файла
		length => undef,                # длина файла
		record => undef,                # id записи в системе Phantom
		call_type => undef,             # входщий/исходяйщий
		call_begin => undef,            # дата и время начала звонка
		call_end => undef,              # дата и время окончания звонка
		call_duration => undef,         # продолжительность звонка в секундах
		call_dialing => undef,          # время дозвона в секундах 
		phone_dialed => undef,          # номер телефона на который звонили
		pulse_dialed => undef,          # строка импульсного набора
		phone_caller => undef,          # номер телефона с которого звонили
		string_dialed => undef,         # полная строка. Номер на который звонили и строка импульсного набора
		channel => undef,               # канал
		string_forwarding => undef,     # строка переадресаций по внутренним телефонам
		time_forwarding => undef,       # время разговоров по вутренним телефонам
		string_dialed_mask => undef,    # маска полной строки набора 0 - символ набранного номера телефона, 1 - символ импульсного набора
		hz_2 => undef,                  # неизвестные данные как-то связанные с внутренней переадресацией,
		human => {
			call_type => undef,         # тип звонка
			channel => undef,           # номер канала
			call_date => undef,         # дата звонка
			call_begin => undef,        # дата и время начала звонка
			call_end => undef,          # дата и время окончания звонка
			call_duration => undef,     # продолжительность звонка в HH:MM:SS формате
			call_dialing => undef       # время дозвона в секундах 
		}

	};
	bless($self,$class);
	if (defined $file) {
		$self->parser_file();
	}
	return $self;
}

# Выводит всю информацию объекте
sub get_info{
	my $self = shift;
	my %object = ();
	map {
		if (substr($_,0,1) ne '_') {
			$object{$_} = $self->{$_};
		}
	} sort (keys (%$self));
	return \%object;
}

# Парсит файл
sub parser_file{
	my $self = shift;
	my $offset = undef;
	my $buffer = undef;
	my $file = undef;

	if (substr($self->{file},-3,-1) eq "ntf") {
		$offset = $self->{_file_offset_ntf};
	} else {
		$offset = $self->{_file_offset_nwu};
	}
	
	open($file, '<:bytes', $self->{file});
	#binmode($file);
	$self->{length} = read $file, $buffer, ($self->{_file_length}+$offset);
	close($file);
	
	$self->{_buffer} = [split('',substr($buffer,$offset,$self->{_file_length}))];
	$self->{_offset} = $offset;
	$self->_parser_channel();
	$self->_parser_call_type();
	$self->_parser_call_begin();
	$self->_parser_call_end();
	$self->_parser_call_duration();
	$self->_parser_call_dialing();
	$self->_parser_phone_dialed();
	$self->_parser_pulse_dialed();
	$self->_parser_phone_caller();
	$self->_parser_record();
	$self->_parser_string_dialed();
	$self->_parser_string_dialed_mask();
	$self->_parser_string_forwarding();
	$self->_parser_hz_2();
}

# Отдает length символов начиная c begin
sub _get_byte{
	my $self = shift;
	my $begin = shift;
	my $length = shift;
	if ($self->{_buffer} && defined $begin && defined $length) {
		$output = join('',@{$self->{_buffer}}[($begin)..($begin+$length-1)]);
	}
	return $output;
} 

# Получает номер канал
sub _parser_channel{
	my $self = shift;
	$self->{channel} = ord($self->_get_byte(0,1));
	$self->{human}->{channel} = int($self->{channel}+1)->bstr();
}

# Получает тип звонка. 1 - исходящий, 0 - входящий
sub _parser_call_type{
	my $self = shift;
	$self->{call_type} = ord($self->_get_byte(8,1));
	$self->{human}->{call_type} = ( ($self->{call_type} == 1) ? 'out' : 'in');
}

# Получает дату и время начала звонка
sub _parser_call_begin{
	my $self = shift;
	my $str = unpack("H16", join('',reverse(split('',$self->_get_byte(12,8)))));
	my $epoch = (hex($str) / 10000000) + $self->{_time_offset};
	$self->{call_begin} = $epoch->bstr();
	my $date = DateTime->from_epoch(epoch => $self->{call_begin});	
	$self->{human}->{call_begin} = $date->ymd('-').' '.$date->hms(':');
	$self->{human}->{call_date} = $date->ymd('.');
	$self->{human}->{call_date_y} = $date->year();
	$self->{human}->{call_date_m} = $date->month();
	$self->{human}->{call_date_d} = $date->day();
}

# Получает дату и время конца звонка
sub _parser_call_end{
	my $self = shift;
	my $str = unpack("H16",join('',reverse(split('',$self->_get_byte(20,8)))));
	my $epoch = (hex($str) / 10000000) + $self->{_time_offset};
	$self->{call_end} = $epoch->bstr();
	my $date = DateTime->from_epoch(epoch => $self->{call_end});
	$self->{human}->{call_end} = $date->ymd('-').' '.$date->hms(':');
}

# Получает продолжительность звонка
sub _parser_call_duration{
	my $self = shift;
	my $duration = $self->{call_end} - $self->{call_begin};
	$self->{call_duration} = $duration;
	$self->{human}->{call_duration} = CCS::Utils::second_to_time($duration);
}

# Получает телефона на который позвонили
sub _parser_phone_dialed{
	my $self = shift;
	my $str = $self->_get_byte(28,32);
	$str =~ s/\x00//g;
	$self->{phone_dialed} = ''.$str;
}

# Получает строку импульсного набора
sub _parser_pulse_dialed{
	my $self = shift;
	my $str = $self->_get_byte(60,32);
	$str =~ s/\x00//g;
	$self->{pulse_dialed} = ''.$str;
}

# Получает телефон с которого звонили(АОН)
sub _parser_phone_caller{
	my $self = shift;
	my $str = $self->_get_byte(92,40);
	$str =~ s/\x00//g;
	$self->{phone_caller} = ''.(($str eq '' || $str == 0) ? 0 : $str);
}

# Получает id звонка в системе Phantom
sub _parser_record{
	my $self = shift;
	my $str = int($self->_get_byte(139,8));
	$self->{record} = $str;
}

# Получает полную строку импульсного набора
sub _parser_string_dialed{
	my $self = shift;
	my $str = $self->_get_byte(464,128);
	$str =~ s/\x00//g;
	$self->{string_dialed} = ''.$str;
}

# Получает маску для разбора полной строки импульсного набора
# на составляющие - телефон на который осуществлялся звонок и строку импульсного набор
sub _parser_string_dialed_mask{
	my $self = shift;
	my $str = $self->_get_byte(592,512);
	$str =~ s/\x00//g;
	$self->{string_dialed_mask} = $str;
}

# Получает строку переадресаций звонка
sub _parser_string_forwarding{
	my $self = shift;
	my $str = $self->_get_byte(1360,256);
	$str =~ s/\x00//g;
	$self->{string_forwarding} = $str;
}

# Получает строку как-то связанную со строкой переадресации звонка
sub _parser_hz_2{
	my $self = shift;
	my $str = $self->_get_byte(1616,256);
	$str =~ s/\x00//g;
	$self->{hz_2} = $str;
}

# Получает время дозвона
sub _parser_call_dialing{
	my $self = shift;
	my $str = unpack("H16",join('',reverse(split('',$self->_get_byte(1872,8)))));
	my $epoch = Math::BigInt->from_hex($str);
	$epoch->bdiv(10000000);
	$self->{call_dialing} = $epoch->bstr();
	$self->{human}->{call_dialing} = CCS::Utils::second_to_time($epoch->bstr());
}

##########################################################
# Далее идут get-методы для отдельного вывода информации #
##########################################################

sub get_call_type{
	my $self = shift;
	return $self->{call_type};
}
sub get_call_begin{
	my $self = shift;
	return $self->{call_begin};
}
sub get_call_begin_human{
	my $self = shift;
	return $self->{human}->{call_begin};
}
sub get_call_end{
	my $self = shift;
	return $self->{call_end};
}
sub get_call_end_human{
	my $self = shift;
	return $self->{human}->{call_end};
}
sub get_call_date_human{
	my $self = shift;
	return $self->{human}->{call_date};
}
sub get_call_duration{
	my $self = shift;
	return $self->{call_duration};
}
sub get_call_duration_human{
	my $self = shift;
	return $self->{human}->{call_duration};
}
sub get_phone_dialed{
	my $self = shift;
	return $self->{phone_dialed};
}
sub get_pulse_dialed{
	my $self = shift;
	return $self->{pulse_dialed};
}
sub get_phone_caller{
	my $self = shift;
	return $self->{phone_caller};
}
sub get_record{
	my $self = shift;
	return $self->{record};
}
sub get_string_dialed{
	my $self = shift;
	return $self->{string_dialed};
}
sub get_string_dialed_mask{
	my $self = shift;
	return $self->{string_dialed_mask};
}
sub get_string_forwarding{
	my $self = shift;
	return $self->{string_forwarding};
}
sub get_hz_2{
	my $self = shift;
	return $self->{hz_2};
}
sub get_call_dialing{
	my $self = shift;
	return $self->{call_dialing};
}

1;