library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;

package vga_package is
	subtype   color_type    is std_logic_vector(11 downto 0);
	subtype   xy_coord_type is integer range 0 to 512;
	constant  COLOR_BLACK   : color_type := X"000";
	constant  COLOR_WHITE   : color_type := X"FFF";
	constant  COLOR_RED     : color_type := X"F00";
	constant  COLOR_ORANGE  : color_type := X"F80";
	constant  COLOR_GREEN   : color_type := X"0F0";
	constant  COLOR_BLUE    : color_type := X"00F";
	constant  COLOR_YELLOW	: color_type := X"FF0";
	constant  COLOR_CYAN		: color_type := X"0FF";
	constant  COLOR_MAGENTA	: color_type := X"F0F";	
end package;

package body vga_package is 


end package body;