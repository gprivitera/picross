library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.picross_package.all;
use work.vga_package.all;


entity Picross_View is
	port
	(
		CLOCK          	: in  std_logic;
		RESET_N        	: in  std_logic;
		
		REDRAW         	: in  std_logic;
		
		FB_READY       	: in  std_logic;
		FB_CLEAR       	: out std_logic;
		FB_DRAW_RECT   	: out std_logic;
		FB_DRAW_LINE   	: out std_logic;
		FB_FILL_RECT   	: out std_logic;
		FB_DRAW_NUMBER 	: out std_logic;
		
		FB_FLIP       	 	: out std_logic;
		
		FB_COLOR      		: out color_type;
		FB_X0         	 	: out xy_coord_type;
		FB_Y0          	: out xy_coord_type;
		FB_X1         	 	: out xy_coord_type;
		FB_Y1          	: out xy_coord_type;
		FB_NUMBER      	: out integer range 0 to 10;
		
		SELECTED_LINE		: in integer range 0 to BOARD_COLUMNS-1;
		SELECTED_TYPE		: rowcol_type;
		
		QUERY_CELL     	: out block_pos_type;
		CELL_CONTENT   	: in  cell_content_type;
		
		-- segnali per richiedere il contenuto di un help
		QUERY_HELP_ROWS 	: out help_row_pos_type;
		QUERY_HELP_COLS 	: out help_col_pos_type;
		-- input da datapath
		HELP_ROW_CONTENT	: in integer range 0 to 10;
		HELP_COL_CONTENT	: in integer range 0 to 10
		
	);
end entity;


architecture RTL of Picross_View is
	constant LEFT_MARGIN    	: integer := 8;
	constant TOP_MARGIN     	: integer := 8;
	constant BLOCK_SIZE     	: integer := 20;
	constant BLOCK_SPACING  	: integer := 1;
	constant NUMBER_HEIGHT 		: integer := 11;
	constant NUMBER_WIDTH 		: integer := 7;
	constant NUMBER_SPACING		: integer := 5;
	constant N_VERT_SPACING		: integer := 3;
	constant N_HORZ_SPACING		: integer := 4;
	constant LEFT_BOARD_MARGIN : integer := LEFT_MARGIN + HELP_SIZE * (NUMBER_WIDTH + NUMBER_SPACING) ; -- 60
	constant TOP_BOARD_MARGIN 	: integer := TOP_MARGIN + HELP_SIZE * (NUMBER_HEIGHT + NUMBER_SPACING) ; -- 80
	
	
	type   state_type    is (IDLE, WAIT_FOR_READY, DRAWING);
	type   substate_type is (CLEAR_SCENE, DRAW_BOARD_OUTLINE, DRAW_BOARD_BLOCKS, DRAW_HELP_ROW, DRAW_HELP_COL, FLIP_FRAMEBUFFER);
	
	signal state        			: state_type;
	signal substate     			: substate_type;
	signal query_cell_r 			: block_pos_type;
	signal query_help_rows_r 	: help_row_pos_type;
	signal query_help_cols_r 	: help_col_pos_type;

begin

	QUERY_CELL <= query_cell_r;
	QUERY_HELP_ROWS <= query_help_rows_r;
	QUERY_HELP_COLS <= query_help_cols_r;

	process(CLOCK, RESET_N)
	begin
	
		if (RESET_N = '0') then
			state             <= IDLE;
			substate          <= CLEAR_SCENE;
			FB_CLEAR          <= '0';
			FB_DRAW_RECT      <= '0';
			FB_DRAW_LINE      <= '0';
			FB_FILL_RECT      <= '0';
			FB_DRAW_NUMBER		<= '0';
			FB_FLIP           <= '0';
			FB_NUMBER			<= 0;
			
			query_cell_r.col  <= 0;
			query_cell_r.row  <= 0;
			query_help_rows_r.row <= 0;
			query_help_rows_r.help <= 0;
			query_help_cols_r.row <= 0;
			query_help_cols_r.help <= 0;
			

		elsif (rising_edge(CLOCK)) then
		
			FB_CLEAR       <= '0';
			FB_DRAW_RECT   <= '0';
			FB_DRAW_LINE   <= '0';
			FB_FILL_RECT   <= '0';
			FB_DRAW_NUMBER <= '0';
			FB_FLIP        <= '0';
			--FB_NUMBER		<= 0;
			
	
			case (state) is
				when IDLE =>
					if (REDRAW = '1') then
						state    <= WAIT_FOR_READY;
						substate <= CLEAR_SCENE;
					end if;
					
				when WAIT_FOR_READY =>
					if (FB_READY = '1') then
						state <= DRAWING;
					end if;
				
				when DRAWING =>
					state <= WAIT_FOR_READY;
				
					case (substate) is
						when CLEAR_SCENE =>
							FB_COLOR     <= COLOR_BLACK;
							FB_CLEAR     <= '1';
							substate     <= DRAW_BOARD_OUTLINE;
						
						when DRAW_BOARD_OUTLINE =>
							FB_COLOR     <= COLOR_RED;
							FB_X0        <= LEFT_MARGIN + LEFT_BOARD_MARGIN;
							FB_Y0        <= TOP_MARGIN + TOP_BOARD_MARGIN;
							FB_X1        <= LEFT_MARGIN + LEFT_BOARD_MARGIN + (BOARD_COLUMNS * BLOCK_SIZE);
							FB_Y1        <= TOP_MARGIN  + TOP_BOARD_MARGIN + (BOARD_ROWS * BLOCK_SIZE);						
							FB_DRAW_RECT <= '1';
							substate     <= DRAW_BOARD_BLOCKS;					
							
						when DRAW_BOARD_BLOCKS =>
							if(CELL_CONTENT = FULL) then
								FB_COLOR 	 <= COLOR_WHITE;
								FB_X0        <= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_cell_r.col * BLOCK_SIZE) + BLOCK_SPACING;
								FB_Y0        <= TOP_MARGIN  + TOP_BOARD_MARGIN + (query_cell_r.row * BLOCK_SIZE) + BLOCK_SPACING;
								FB_X1        <= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_cell_r.col * BLOCK_SIZE) + BLOCK_SIZE - BLOCK_SPACING;
								FB_Y1        <= TOP_MARGIN  + TOP_BOARD_MARGIN + (query_cell_r.row * BLOCK_SIZE) + BLOCK_SIZE - BLOCK_SPACING;
								FB_FILL_RECT <= '1';
							elsif(CELL_CONTENT = MARKED) then
								FB_COLOR 	 <= COLOR_MAGENTA;
								FB_X0        <= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_cell_r.col * BLOCK_SIZE) + BLOCK_SPACING ;
								FB_Y0        <= TOP_MARGIN  + TOP_BOARD_MARGIN + (query_cell_r.row * BLOCK_SIZE) + BLOCK_SPACING ;
								FB_X1        <= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_cell_r.col * BLOCK_SIZE) + BLOCK_SIZE - BLOCK_SPACING;
								FB_Y1        <= TOP_MARGIN  + TOP_BOARD_MARGIN + (query_cell_r.row * BLOCK_SIZE) + BLOCK_SIZE - BLOCK_SPACING;
								FB_FILL_RECT <= '1';								
							end if;
					
							if (query_cell_r.col /= BOARD_COLUMNS-1) then
								query_cell_r.col <= query_cell_r.col + 1;
							else
								query_cell_r .col <= 0;
								if (query_cell_r.row /= BOARD_ROWS-1) then
									query_cell_r.row <= query_cell_r.row + 1;
								else
									query_cell_r.row <= 0;
									substate  <= DRAW_HELP_ROW;
								end if;
							end if;
							
						when DRAW_HELP_ROW =>
							if query_help_rows_r.row = SELECTED_LINE and SELECTED_TYPE = ROW then
								FB_COLOR <= COLOR_YELLOW;
							else
								FB_COLOR <= COLOR_BLUE;
							end if;
							FB_X0 	<= LEFT_MARGIN + (((HELP_SIZE-1) - query_help_rows_r.help) * (NUMBER_WIDTH + NUMBER_SPACING));
							FB_Y0		<= TOP_MARGIN + TOP_BOARD_MARGIN + (query_help_rows_r.row * BLOCK_SIZE + N_VERT_SPACING);
							FB_X1 	<= LEFT_MARGIN + (((HELP_SIZE-1) - query_help_rows_r.help) *(NUMBER_WIDTH + NUMBER_SPACING)) + NUMBER_WIDTH;
							FB_Y1		<= TOP_MARGIN + TOP_BOARD_MARGIN + (query_help_rows_r.row * BLOCK_SIZE + N_VERT_SPACING)+ NUMBER_HEIGHT;
							FB_NUMBER <= HELP_ROW_CONTENT;
							FB_DRAW_NUMBER <= '1';							
							
							
							if (query_help_rows_r.help /= (HELP_SIZE-1)) then	-- cicla sugli aiuti (da 0 a 4)
								query_help_rows_r.help <= query_help_rows_r.help + 1;
							else -- finito di disegnare una riga
								query_help_rows_r.help <= 0;
								if (query_help_rows_r.row /= BOARD_ROWS-1) then
									query_help_rows_r.row <= query_help_rows_r.row + 1; -- incremento riga
								else
									query_help_rows_r.row <= 0;
									substate <= DRAW_HELP_COL; -- finito disegno righe di aiuti, passo alle colonne
								end if;
							end if;
								
							
						when DRAW_HELP_COL =>
							if query_help_cols_r.row = SELECTED_LINE and SELECTED_TYPE = COL then
								FB_COLOR <= COLOR_YELLOW;
							else
								FB_COLOR <= COLOR_BLUE;
							end if;
							FB_X0 	<= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_help_cols_r.row * BLOCK_SIZE + N_HORZ_SPACING);
							FB_Y0		<= TOP_MARGIN + (((HELP_SIZE-1) - query_help_cols_r.help) * (NUMBER_HEIGHT+ NUMBER_SPACING));							
							FB_X1 	<= LEFT_MARGIN + LEFT_BOARD_MARGIN + (query_help_cols_r.row * BLOCK_SIZE + N_HORZ_SPACING) + NUMBER_WIDTH;
							FB_Y1		<= TOP_MARGIN + (((HELP_SIZE-1) - query_help_cols_r.help) * (NUMBER_HEIGHT + NUMBER_SPACING))+ NUMBER_HEIGHT;
							FB_NUMBER <= HELP_COL_CONTENT;
							FB_DRAW_NUMBER <= '1';
							
							if (query_help_cols_r.help /= (HELP_SIZE-1)) then
								query_help_cols_r.help <= query_help_cols_r.help + 1;
							else
								query_help_cols_r.help <= 0;
								if (query_help_cols_r.row /= BOARD_COLUMNS-1) then
									query_help_cols_r.row <= query_help_cols_r.row + 1;
								else
									query_help_cols_r.row <= 0;
									substate <= FLIP_FRAMEBUFFER;
								end if;
							end if;
							

						when FLIP_FRAMEBUFFER =>
							FB_FLIP  <= '1';
							state    <= IDLE;						
							
					end case;
			end case;
	
		end if;
	end process;
	
end architecture;
