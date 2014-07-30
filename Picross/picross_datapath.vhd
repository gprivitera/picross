library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.picross_package.all;
--use work.vga_package.all;


entity Picross_Datapath is
	port
	(
		CLOCK           : in  std_logic;
		RESET_N         : in  std_logic;
		
		-- Connections for the Controller
		CLEAR           : in  std_logic;
--		SOLVE_REQ					: in std_logic;
--		SOLVE_ACK					: out std_logic;
		
		-- input per modifiche board
		SET_LINE				: in std_logic;	
		SET_LINE_TYPE		: in rowcol_type;
		SET_LINE_INDEX		: in integer range 0 to BOARD_COLUMNS-1;
		SET_LINE_CONTENT	: in linea_type;
		
		-- query line/helpline (i/o per controller)
		QUERY_LINE			: in line_query_type;
		LINE_CONTENT		: out linea_type;
		HELP_LINE_CONTENT : out help_type;

		MAX_JOB_REQ			: in std_logic;
		MAX_JOB_ACK			: out std_logic;
		MAX_JOB_RESULT		: out max_job_type;
					
		-- Connections for the View
		QUERY_CELL      		: in  block_pos_type;
		CELL_CONTENT    		: out cell_content_type;		
		SELECTED_LINE_INDEX	:	out integer range 0 to BOARD_COLUMNS-1;
		SELECTED_LINE_TYPE	: out rowcol_type;
		-- segnali inviati da View per richiedere il contenuto degli help
		QUERY_HELP_ROWS 		: in  help_row_pos_type;
		QUERY_HELP_COLS		: in	 help_col_pos_type;
		-- output per la View, un numero da 0 a 10 - 0 se non c'Ã¨ suggerimento
		HELP_ROW_CONTENT		: out integer range 0 to 10;
		HELP_COL_CONTENT		: out integer range 0 to 10
	);

end entity;


architecture RTL of Picross_Datapath is
	signal board					: board_type;
	signal help_boards			: help_boards_type;		
	signal jobs						: jobs_array;	
	signal no_jobs					: std_logic;
	--
	type find_max_state_type is (IDLE, COMPUTING);
	signal find_max_state 		: find_max_state_type; 
	signal find_max_i				: integer range 0 to BOARD_ROWS+BOARD_COLUMNS;
begin

	SELECTED_LINE_INDEX <= QUERY_LINE.index;
	SELECTED_LINE_TYPE <= QUERY_LINE.rowcol;

	Board_rtl : process(CLOCK, RESET_N)
	begin
		help_boards <= HELP_COLS_TEST;
		if (RESET_N = '0') then
			help_boards <= HELP_COLS_TEST;
			for col in 0 to BOARD_COLUMNS-1 loop
				for row in 0 to BOARD_ROWS-1 loop
					board.cells(col,row) <= EMPTY;
				end loop;
			end loop;
			
		elsif (rising_edge(CLOCK)) then
			
			if( set_line = '1' ) then
				case (set_line_type) is 
					when ROW =>
						for i in 0 to BOARD_COLUMNS-1 loop
							if set_line_content(i) /= EMPTY then
								board.cells(i, set_line_index) <= set_line_content(i);									
							end if;
						end loop;
					when COL =>
						for i in 0 to BOARD_COLUMNS-1 loop
							if set_line_content(i) /= EMPTY then
								board.cells(set_line_index, i) <= set_line_content(i);
							end if;
						end loop;					
				end case;
			end if;
			
			if (CLEAR = '1') then
				for col in 0 to BOARD_COLUMNS-1 loop
					for row in 0 to BOARD_ROWS-1 loop
						board.cells(col,row) <= EMPTY;
					end loop;
				end loop;
			end if;
			
		end if;
	end process;

	Jobs_rtl : process(CLOCK, RESET_N)
	begin 
		if RESET_N = '0' then
			for i in 0 to BOARD_ROWS - 1 loop
				jobs(i).score 			<= LINE_SCORE(i, ROW, help_boards);
				jobs(i).is_active		<= '1';
				jobs(i).index			<= i;
				jobs(i).line_type		<= ROW;
			end loop;
			
			for j in 0 to BOARD_COLUMNS - 1 loop				
				jobs(j+BOARD_ROWS).score 			<= LINE_SCORE(j, COL, help_boards);
				jobs(j+BOARD_ROWS).is_active		<= '1';
				jobs(j+BOARD_ROWS).index			<= j;
				jobs(j+BOARD_ROWS).line_type		<= COL;
			end loop;
			
		elsif rising_edge(CLOCK) then
		
			if( SET_LINE = '1' ) then
				case (SET_LINE_TYPE) is 
					when ROW =>
						for i in 0 to BOARD_ROWS-1 loop
							if SET_LINE_CONTENT(i) /= EMPTY then
								if board.cells(i, SET_LINE_INDEX) /= SET_LINE_CONTENT(i) then
									--aggiorna job().score per COLONNA i -- indice BOARD_ROWS-1+i
									jobs(BOARD_ROWS+i).score <= jobs(BOARD_ROWS+i).score + 1;
									jobs(BOARD_ROWS+i).is_active <= '1';									
								end if;									
							end if;
						end loop;
						jobs(SET_LINE_INDEX).is_active <= '0';
					when COL =>
						for i in 0 to BOARD_COLUMNS-1 loop
							if SET_LINE_CONTENT(i) /= EMPTY then
								if board.cells(SET_LINE_INDEX, i) /= SET_LINE_CONTENT(i) then
									--aggiorna job().score per RIGA i -- indice i
									jobs(i).score <= jobs(i).score + 1;
									jobs(i).is_active <= '1';
								end if;
							end if;
						end loop;
						jobs(SET_LINE_INDEX+BOARD_ROWS).is_active <= '0';					
				end case;
			elsif ( CLEAR = '1' ) then
				for i in 0 to BOARD_ROWS - 1 loop
					jobs(i).score 			<= LINE_SCORE(i, ROW, help_boards);
					jobs(i).is_active		<= '1';
					jobs(i).index			<= i;
					jobs(i).line_type		<= ROW;
				end loop;
				
				for j in 0 to BOARD_COLUMNS - 1 loop				
					jobs(j+BOARD_ROWS).score 			<= LINE_SCORE(j, COL, help_boards);
					jobs(j+BOARD_ROWS).is_active		<= '1';
					jobs(j+BOARD_ROWS).index			<= j;
					jobs(j+BOARD_ROWS).line_type		<= COL;
				end loop;
			end if;
		end if;
	end process;
	
	FindMaxJob : process(CLOCK, RESET_N)
	variable max_score : integer := 0;
	variable max_job_index : integer;
	variable max_job_type	: rowcol_type;
	variable inactive_jobs	: integer;
	begin 
		if RESET_N = '0' then
			
		elsif rising_edge(CLOCK) then
			
			case(find_max_state) is
				
				when IDLE =>
					MAX_JOB_ACK <= '0';
					
					if( MAX_JOB_REQ = '1' ) then
						max_job_index := 0;
						max_job_type := ROW;
						max_score := -126;
						inactive_jobs:=0;
						find_max_i <= 0;
						find_max_state <= COMPUTING;
					end if;
					
				when COMPUTING =>
				
					if find_max_i < BOARD_COLUMNS + BOARD_ROWS then
						if jobs(find_max_i).score > max_score and jobs(find_max_i).is_active = '1' then
							max_score := jobs(find_max_i).score;
							max_job_index := jobs(find_max_i).index;
							max_job_type := jobs(find_max_i).line_type;
						end if;
						if jobs(find_max_i).is_active='0' then
							inactive_jobs:=inactive_jobs+1;
						end if;
						find_max_i <= find_max_i + 1;
					else 
						MAX_JOB_ACK <= '1';
						MAX_JOB_RESULT.index <= max_job_index;
						MAX_JOB_RESULT.rowcol <= max_job_type;
						MAX_JOB_RESULT.inactive_jobs <= inactive_jobs;
						find_max_state <= IDLE;
					end if;
				
			end case;
		end if;
	end process;
	
	CellQuery : process(QUERY_CELL, board)
		variable selected_cell : cell_content_type;
	begin
		selected_cell := board.cells(QUERY_CELL.col, QUERY_CELL.row);
		-- At first attempt output the selected board cell
		CELL_CONTENT <= selected_cell; --setto l'output
	end process;
	
	HelpRowCellQuery : process(QUERY_HELP_ROWS, help_boards)
	begin
		HELP_ROW_CONTENT <= help_boards.rows(QUERY_HELP_ROWS.row, (HELP_SIZE-1) - QUERY_HELP_ROWS.help); 
	end process;
	
	HelpColCellQuery : process(QUERY_HELP_COLS, help_boards)
	begin
		HELP_COL_CONTENT <= help_boards.cols(QUERY_HELP_COLS.row, (HELP_SIZE-1) - QUERY_HELP_COLS.help); 
	end process;
	
	LineQuery : process(QUERY_LINE, board, help_boards)
	begin
		LINE_CONTENT 		<= GET_LINE(board, QUERY_LINE.index, QUERY_LINE.rowcol);
		HELP_LINE_CONTENT <= GET_HELP(help_boards, QUERY_LINE.index, QUERY_LINE.rowcol);		
	end process;

	
end architecture;