library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.vga_package.all;

package picross_package is
	constant BOARD_COLUMNS 	: positive	:= 10;
	constant BOARD_ROWS 		: positive	:= 10;
	constant HELP_SIZE		: positive  :=  5;
	
	-- enum per le celle: vuota, piena o segnata (croce che indica che sarà sicuramente vuota)
	type cell_content_type	is	(EMPTY, FULL, MARKED);
	type rowcol_type is (ROW, COL);
	attribute enum_encoding :	string;
	attribute enum_encoding of cell_content_type : type is "sequential";
	-- sequential usa numeri binari - 00, 01, 10
	
	-- la board è una matrice 
	type board_array is array( natural range <>, natural range <>) of cell_content_type;
	
	type board_type is record
		cells			: board_array(0 to (BOARD_COLUMNS-1), 0 to (BOARD_ROWS-1));
	end record;
	
	type block_pos_type is record
		col         : integer range 0 to (BOARD_COLUMNS-1);
		row         : integer range 0 to (BOARD_ROWS-1);
	end record;
	
	-- tipi per gli help 
	
	type help_array is array( natural range <>, natural range <>) of integer range 0 to BOARD_COLUMNS;
	
	type help_boards_type is record
		rows			: help_array(0 to (BOARD_ROWS-1), 0 to HELP_SIZE-1);
		cols 			: help_array(0 to (BOARD_COLUMNS-1), 0 to HELP_SIZE-1);
	end record;
	
	type help_row_pos_type is record
		row 			: integer range 0 to (BOARD_ROWS - 1);
		help 			: integer range 0 to 4;
	end record;
	
	type help_col_pos_type is record
		row 			: integer range 0 to (BOARD_COLUMNS - 1);
		help 			: integer range 0 to 4;
	end record;
	
	-- tipi per la query linea/help
	
	type line_query_type is record
		index 	: integer range 0 to BOARD_COLUMNS-1;
		rowcol	: rowcol_type;
	end record;
	
	type help_query_type is record
		index 	: integer range 0 to BOARD_COLUMNS-1;
		rowcol	: rowcol_type;
	end record;
	

	
	type job_type is record
		is_active	: std_logic;
		index			: integer range 0 to (BOARD_COLUMNS - 1);
		line_type	: rowcol_type;
		score			: integer range -126 to 127;
	end record;
	
	type max_job_type is record
		index			: integer range 0 to (BOARD_COLUMNS - 1);
		rowcol	   : rowcol_type;
		inactive_jobs : integer range 0 to (BOARD_COLUMNS+BOARD_ROWS);
	end record;
	
	type jobs_array is array( 0 to BOARD_COLUMNS+BOARD_ROWS-1 ) of job_type;
	
	type cell_score is record
		row			: integer range 0 to (BOARD_COLUMNS-1);
		col			: integer range 0 to (BOARD_ROWS-1);
		score			: integer range -126 to 127;
		color			: cell_content_type;
	end record;
	
	type cell_scores is array(0 to BOARD_COLUMNS*BOARD_ROWS) of cell_score;
	
	constant HELP_COLS_TEST : help_boards_type :=
	(
		cols  => 
		(
			--(1,0,0,0,0), (1,1,0,0,0), (1,3,0,0,0), (4,2,0,0,0), (5,1,1,0,0), (1,6,1,0,0), (2,2,1,0,0), (1,1,0,0,0), (1,0,0,0,0), (0,0,0,0,0) --sciatore
			(1,0,0,0,0), (2,1,0,0,0), (2,1,1,0,0), (5,2,1,0,0), (2,3,2,0,0), (5,1,0,0,0), (1,4,2,0,0), (3,1,2,1,0), (4,1,0,0,0), (1,1,0,0,0) --fungo
         --(4,0,0,0,0),(1,2,0,0,0), (1,1,1,0,0), (1,6,0,0,0), (1,5,1,0,0), (7,1,0,0,0), (1,1,4,0,0), (1,1,2,1,0), (1,3,1,0,0), (1,1,0,0,0) --elicottero
			--(3,1,0,0,0,0,0,0), (9,0,0,0,0,0,0,0), (10,0,0,0,0,0,0,0), (10,0,0,0,0,0,0,0), (2,1,0,0,0,0,0,0), (1,1,0,0,0,0,0,0), (8,0,0,0,0,0,0,0), (1,1,1,0,0,0,0,0), (1,1,3,0,0,0,0,0), (1,2,3,0,0,0,0,0), (1,2,4,0,0,0,0,0), (1,1,2,0,0,0,0,0), (1,1,1,0,0,0,0,0), (8,0,0,0,0,0,0,0), (1,0,0,0,0,0,0,0)  --altalena
			),
		rows =>
		(
			--(3,0,0,0,0), (1,1,0,0,0), (1,3,0,0,0), (5,0,0,0,0), (4,0,0,0,0), (1,2,1,1,0), (2,2,0,0,0), (2,1,0,0,0), (1,1,0,0,0), (2,2,0,0,0) --sciatore
			(5,0,0,0,0), (4,2,0,0,0), (3,4,0,0,0), (1,4,2,0,0), (7,0,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (1,1,0,0,0), (10,0,0,0,0)	--fungo
			--(0,0,0,0,0), (9,0,0,0,0), (1,0,0,0,0), (4,0,0,0,0), (1,3,1,0,0), (2,3,1,0,0), (9,0,0,0,0), (1,5,0,0,0), (1,1,1,0,0), (7,0,0,0,0) --elicottero
			--(1,13,0,0,0,0,0,0), (5,1,1,0,0,0,0,0), (4,1,2,1,0,0,0,0), (3,1,2,1,0,0,0,0), (3,3,3,0,0,0,0,0), (3,1,2,1,0,0,0,0), (3,1,4,1,0,0,0,0), (3,8,0,0,0,0,0,0), (3,1,1,0,0,0,0,0), (6,0,0,0,0,0,0,0), (0,0,0,0,0,0,0,0), (0,0,0,0,0,0,0,0), (0,0,0,0,0,0,0,0), (0,0,0,0,0,0,0,0), (0,0,0,0,0,0,0,0)  --altalena
		)
	);
	
	--- tipi per le funzioni di risoluzione
	type	 temp_array_type is array (0 to BOARD_ROWS -1) of integer;
	type	 help_type is array (0 to (BOARD_ROWS/2)-1) of integer;
	type	 help_array_type is array (0 to BOARD_ROWS-1) of help_type;	
	type	 linea_type is array(0 to BOARD_ROWS -1) of cell_content_type;
	
	function GET_LENGTH(help: help_type) return integer;	
	function GET_LINE(board: board_type; index: integer; rowcol: rowcol_type) return linea_type;
	function GET_HELP(help_board: help_boards_type; index: integer; rowcol: rowcol_type) return help_type;
	function LINE_SCORE(index: integer; line_type : rowcol_type; help_board : help_boards_type) return integer;
	
end package;

package body picross_package is

	function GET_LINE(board: board_type; index: integer; rowcol: rowcol_type) return linea_type is
		variable result : linea_type;
	begin
		case (rowcol) is
			when ROW => 
				for i in 0 to BOARD_ROWS-1 loop
					result(i) := board.cells(i,index);
				end loop;
			when COL =>
				for i in 0 to BOARD_COLUMNS-1 loop
					result(i) := board.cells(index, i);
				end loop;
		end case;
		return result;
	end GET_LINE;
	
	function GET_HELP(help_board: help_boards_type; index: integer; rowcol: rowcol_type) return help_type is
		variable result: help_type;
	begin
		case (rowcol) is 
			when ROW =>
				for i in 0 to (BOARD_ROWS/2)-1 loop
					result(i) := help_board.rows(index,i);
				end loop;
			when COL => 
				for i in 0 to (BOARD_ROWS/2)-1 loop
					result(i) := help_board.cols(index,i);
				end loop;
			end case;
		return result;
	end GET_HELP;
	
	function GET_LENGTH(help: help_type) return integer is
		variable  length : integer := 0;
	begin
		for i in help' range loop
			if help(i)>0 then
				length:=length+1;
			end if;
		end loop;
		if length > 0 then
			return length;
		else
			return 1;
		end if;
	end GET_LENGTH;
			
	function GET_ARRAY_LENGTH(temp: temp_array_type) return integer is
		variable length				:	integer;
	begin
		length:=0;
		for i in temp' range loop
			if temp(i) >= 0 then
				length:=length+1;
			end if;
		end loop;
		return length;
	end GET_ARRAY_LENGTH;
	
	function LINE_SCORE(index: integer; line_type : rowcol_type; help_board : help_boards_type) return integer is
		variable sum : integer range 0 to BOARD_COLUMNS+BOARD_ROWS := 0;
	begin
		case (line_type) is 
			when ROW =>				
				for i in 0 to (BOARD_ROWS/2)-1 loop
					sum := sum + help_board.rows(index, i);
				end loop;				
			when COL =>
				for i in 0 to (BOARD_COLUMNS/2)-1 loop
					sum := sum + help_board.cols(index, i);
				end loop;
		end case;
		return sum;
	end LINE_SCORE;
	


	function LINE_SCORE_S(board: board_type; index: integer; line_type : rowcol_type; help_board : help_boards_type) return integer is
		variable B	:	integer;
		variable N	:	integer;
		variable L	: 	integer;
		variable help 			:  help_type;
	begin
		L := BOARD_COLUMNS;
		help  := GET_HELP(help_board, index, line_type);
		N := GET_LENGTH(help);
		B := 0;
		
		for i in 0 to (BOARD_COLUMNS/2)-1 loop
			if i < N then
				B := B + help(i);
			end if;	
		end loop;
		
		if B=L then
			return L;
		else
			return B*(N+1)+N*(N-L-1); 
		end if;
	end LINE_SCORE_S;

end package body;
	
	