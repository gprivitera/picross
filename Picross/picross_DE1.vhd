library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.picross_package.all;
use work.vga_package.all;

entity Picross_DE1 is
port
	(
		CLOCK_50            : in  std_logic;
		KEY                 : in  std_logic_vector(3 downto 0);
		LEDR					  : out std_logic_vector(9 downto 0);
		LEDG					  : out std_logic_vector(7 downto 0);
		
		SW                  : in  std_logic_vector(9 downto 7);
		VGA_R               : out std_logic_vector(3 downto 0);
		VGA_G               : out std_logic_vector(3 downto 0);
		VGA_B               : out std_logic_vector(3 downto 0);
		VGA_HS              : out std_logic;
		VGA_VS              : out std_logic;
		
		SRAM_ADDR           : out   std_logic_vector(17 downto 0);
		SRAM_DQ             : inout std_logic_vector(15 downto 0);
		SRAM_CE_N           : out   std_logic;
		SRAM_OE_N           : out   std_logic;
		SRAM_WE_N           : out   std_logic;
		SRAM_UB_N           : out   std_logic;
		SRAM_LB_N           : out   std_logic
	);
end;

architecture RTL of Picross_DE1 is

	signal clock              	: std_logic;
	signal clock_vga          	: std_logic;
	signal RESET_N            	: std_logic;
	signal redraw				  	: std_logic;
	signal fb_ready           	: std_logic;
	signal fb_clear           	: std_logic;
	signal fb_flip            	: std_logic;
	signal fb_draw_rect       	: std_logic;
	signal fb_fill_rect       	: std_logic;
	signal fb_draw_line       	: std_logic;
	signal fb_draw_number	  	: std_logic;
	signal fb_x0              	: xy_coord_type;
	signal fb_y0              	: xy_coord_type;
	signal fb_x1            	: xy_coord_type;
	signal fb_y1           	   : xy_coord_type;
	signal fb_number			  	: integer range 0 to 10;
	signal fb_color           	: color_type;
	signal time_10ms				: std_logic;
	signal query_line				: line_query_type;
	signal line_content		 	: linea_type;
	signal help_line_content 	: help_type;
	signal query_help_rows	  	: help_row_pos_type;
	signal query_help_cols    	: help_col_pos_type;
	signal help_row_content   	: integer range 0 to 10;
	signal help_col_content   	: integer range 0 to 10;
	signal query_cell         	: block_pos_type;
	signal query_cell_content	: cell_content_type;
	signal max_job_req 			: std_logic;
	signal max_job_ack			: std_logic;
	signal max_job_result		: max_job_type;
	signal set_line			  	: std_logic;	
	signal set_line_type		  	: rowcol_type;
	signal set_line_index	  	: integer range 0 to BOARD_COLUMNS-1;		
	signal set_line_content	  	: linea_type;
	signal reset_sync_reg     	: std_logic;
	signal clear           	  	: std_logic;
	signal nextstep				: std_logic;
	signal continue				: std_logic;
	signal solve_req				: std_logic;
	signal solve_ack				: std_logic;
	signal selected_line_index	: integer range 0 to BOARD_COLUMNS-1;
	signal selected_line_type	: rowcol_type;

begin

	pll : entity work.PLL
		port map (
			inclk0  => CLOCK_50,
			c0      => clock_vga,
			c1      => clock
		); 					
	
	reset_sync : process(CLOCK_50)
	begin
		if (rising_edge(CLOCK_50)) then
			reset_sync_reg <= SW(9);
			RESET_N <= reset_sync_reg;
		end if;
	end process;


	vga : entity work.VGA_Framebuffer
		port map (
			CLOCK     => clock_vga,
			RESET_N   => RESET_N,
			READY     => fb_ready,
			COLOR     => fb_color,
			CLEAR     => fb_clear,
			DRAW_RECT => fb_draw_rect,
			FILL_RECT => fb_fill_rect,
			DRAW_LINE => fb_draw_line,
			DRAW_NUMBER => fb_draw_number,
			FLIP      => fb_flip,	
			X0        => fb_x0,
			Y0        => fb_y0,
			X1        => fb_x1,
			Y1        => fb_y1,
			NUMBER	 => fb_number,
				
			VGA_R     => VGA_R,
			VGA_G     => VGA_G,
			VGA_B     => VGA_B,
			VGA_HS    => VGA_HS,
			VGA_VS    => VGA_VS,
		
			SRAM_ADDR => SRAM_ADDR,
			SRAM_DQ   => SRAM_DQ,			
			SRAM_CE_N => SRAM_CE_N,
			SRAM_OE_N => SRAM_OE_N,
			SRAM_WE_N => SRAM_WE_N,
			SRAM_UB_N => SRAM_UB_N,
			SRAM_LB_N => SRAM_LB_N
		);
		
	datapath : entity work.picross_datapath
		port map (
			CLOCK           		=> clock,
			RESET_N         		=> RESET_N,
			CLEAR           		=> clear,			
			SET_LINE					=> set_line,
			SET_LINE_TYPE			=>	set_line_type,
			SET_LINE_INDEX			=>	set_line_index,		
			SET_LINE_CONTENT		=> set_line_content,
			QUERY_LINE				=> query_line,
			LINE_CONTENT			=> line_content,
			HELP_LINE_CONTENT  	=> help_line_content,
			QUERY_CELL     		=> query_cell,
			CELL_CONTENT   		=> query_cell_content,
			QUERY_HELP_ROWS		=> query_help_rows,
			QUERY_HELP_COLS		=> query_help_cols,
			SELECTED_LINE_INDEX  => selected_line_index,
			SELECTED_LINE_TYPE   => selected_line_type,
			HELP_ROW_CONTENT 		=> help_row_content,
			HELP_COL_CONTENT 		=> help_col_content,
			MAX_JOB_REQ				=> max_job_req,
			MAX_JOB_ACK				=> max_job_ack,
			MAX_JOB_RESULT			=> max_job_result
		);
		
		
	view : entity work.picross_view
		port map (
			CLOCK           => clock,
			RESET_N         => RESET_N,
			REDRAW          => redraw,
			FB_READY        => fb_ready,
			FB_CLEAR        => fb_clear,
			FB_DRAW_RECT    => fb_draw_rect,
			FB_DRAW_LINE    => fb_draw_line,
			FB_FILL_RECT    => fb_fill_rect,
			FB_DRAW_NUMBER	 => fb_draw_number,
			FB_FLIP         => fb_flip,
			FB_COLOR        => fb_color,
			FB_X0           => fb_x0,
			FB_Y0           => fb_y0,
			FB_X1           => fb_x1,
			FB_Y1           => fb_y1,
			FB_NUMBER		 => fb_number,
			QUERY_CELL      => query_cell,
			CELL_CONTENT    => query_cell_content,
			QUERY_HELP_ROWS => query_help_rows,
			QUERY_HELP_COLS => query_help_cols,
			SELECTED_LINE   => selected_line_index,
			SELECTED_TYPE   => selected_line_type,
			HELP_ROW_CONTENT => help_row_content,
			HELP_COL_CONTENT => help_col_content
		);
		
	controller : entity work.picross_controller
		port map (
			CLOCK 				=> clock,
			TIME_10MS 			=> time_10ms,
			RESET_N				=> RESET_N,
			REDRAW				=> redraw,
			CLEAR					=> clear,
			BUTTON1				=> not(KEY(3)),
			BUTTON2				=> not(KEY(2)),
			STEP_I				=> SW(8),
			STEP_LR				=> SW(7),
			LEDG					=>	 LEDG,
			QUERY_LINE			=> query_line,
			LINE_CONTENT		=> line_content,
			HELP_LINE_CONTENT => help_line_content,			
			SET_LINE				=> set_line,
			SET_LINE_TYPE		=>	set_line_type,
			SET_LINE_INDEX		=>	set_line_index,		
			SET_LINE_CONTENT	=> set_line_content,
			MAX_JOB_REQ			=> max_job_req,
			MAX_JOB_ACK			=> max_job_ack,
			MAX_JOB_RESULT		=> max_job_result
		);
		
	timegen : process(CLOCK, RESET_N)
		variable counter : integer range 0 to (500000-1);
	begin
		if (RESET_N = '0') then
			counter := 0;
			time_10ms <= '0';
		elsif (rising_edge(clock)) then
			if(counter = 499999) then --counter'high) then
				counter := 0;
				time_10ms <= '1';
			else
				counter := counter+1;
				time_10ms <= '0';			
			end if;
		end if;
	end process;
	
end architecture;

