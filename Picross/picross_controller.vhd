library ieee;
use ieee.numeric_std.all;
use ieee.std_logic_1164.all;
use work.picross_package.all;

entity Picross_Controller is
        port
        (
        	CLOCK           	: in std_logic;
        	RESET_N         	: in std_logic;
			BUTTON1				: in std_logic;
			BUTTON2				: in std_logic;
			STEP_I				: in std_logic;
			STEP_LR				: in std_logic;
			LEDG				: out std_logic_vector(7 downto 0);	
			LEDR				: out std_logic_vector(9 downto 0);
			TIME_10MS		 	: in std_logic;

           -- Connections with Picross_Datapath
       		CLEAR           	: out std_logic;
			SET_LINE			: out std_logic;	
			SET_LINE_TYPE		: out rowcol_type;
			SET_LINE_INDEX		: out integer range 0 to BOARD_COLUMNS-1;		
			SET_LINE_CONTENT	: out linea_type;
			
			MAX_JOB_REQ			: out std_logic;
			MAX_JOB_ACK			: in std_logic;
			MAX_JOB_RESULT		: in max_job_type;
			
			QUERY_LINE			: out line_query_type;
			LINE_CONTENT		: in linea_type;					
			HELP_LINE_CONTENT 	: in help_type;
							
            -- Connections with View
        	REDRAW          	: out std_logic	 
        );
end entity;


architecture RTL of Picross_Controller is

	signal  count				  : integer range 0 to 25;
	
	type debounce_type is (IDLE, BUTTONPRESS, WAITRELEASE);
	signal debounce_state 	: debounce_type := IDLE;
	signal debounce_state2 	: debounce_type := IDLE;
	signal debounce_state3 	: debounce_type := IDLE;
		
--	type solve_state_type is (IDLE, FETCH,WAITFORSOL, NEWLINE);
	type intersect_state_type is (IDLE, WAITFORSOL, COMPUTING);
	-- per left/rightmost
	type solfind_state_type is (NEWBLOCK, PLACEBLOCK, FINALSPACE, CHECKREST, BACKTRACK, ADVANCEBLOCK, HALT, IDLE);
	type solfind_substate_type is (LOOPING_1, LOOPING_2, SEQ);
	type logic_solve_state_type is (IDLE, FINDMAXLINE, FETCH, WAITFORSOL, NEWLINE);
	-- per left/rightmost
	signal leftmost_state		: solfind_state_type;
	signal leftmost_substate	: solfind_substate_type;
	signal rightmost_state		: solfind_state_type;
	signal rightmost_substate	: solfind_substate_type;
	-- input leftmost
	signal leftmost_req			: std_logic;
	signal leftmost_rowcol_req	: rowcol_type; -- tipo linea richiesta (riga o colonna)
	signal leftmost_line_req 	: integer range 0 to BOARD_COLUMNS-1; -- numero linea		
	-- output leftmost 
	signal leftmost_pos			: help_type := ( others => -1 ); -- posizioni soluzione a sinistra
	signal leftmost_success		: std_logic; -- '1' se successo
	signal leftmost_ack			: std_logic; -- '1' se terminato
	-- input rightmost
	signal rightmost_req			: std_logic;
	signal rightmost_rowcol_req	: rowcol_type; -- tipo linea richiesta (riga o colonna)
	signal rightmost_line_req 	: integer range 0 to BOARD_COLUMNS-1; -- numero linea		
	-- output rightmost 
	signal rightmost_pos			: help_type := ( others => -1 ); -- posizioni soluzione a sinistra
	signal rightmost_success	: std_logic; -- '1' se successo
	signal rightmost_ack			: std_logic; -- '1' se terminato
	
	signal linea_out				: linea_type;
	signal line_index 			: integer range 0 to BOARD_COLUMNS-1 :=0;
	signal line_type 				: rowcol_type	:= ROW; 	
	signal line_input	: linea_type; -- linea usata da left/rightmost
	signal help_input  : help_type;  -- help ''
	
	signal intersect_req			: std_logic;
	signal intersect_state		: intersect_state_type;
	signal intersect_ack			: std_logic;
	signal intersect_output		: linea_type;
	signal intersect_success	: std_logic;
	signal solfind_fail			: std_logic;
	signal solfind_success 		: std_logic;
	signal logic_solve_state	: logic_solve_state_type;
	signal logic_solve_i			: integer range 0 to BOARD_COLUMNS+BOARD_ROWS;
	signal logic_solve_req		: std_logic;
	signal probe_solve_req		: std_logic;
	signal logic_solve_ack		: std_logic;

	signal nextstep				: std_logic;
	signal continue				: std_logic;
	
begin

	Controller_RTL : process (CLOCK, RESET_N)
		variable button_status	: std_logic := '0';
		begin
			
			if (RESET_N = '0') then
				CLEAR 	<= '1';
				REDRAW 	<= '0';
				button_status :='0';
			elsif rising_edge(CLOCK) then	
				CLEAR <= '0';
				
				if button_status = '0' then
					logic_solve_req <='1';
					button_status := '1';				
				else			
					logic_solve_req <='0';
				end if;
					
				if(TIME_10MS = '1' and count = 3) then  -- 30ms - circa 33 refresh/sec
					count <= 0;
					REDRAW <= '1';
				elsif( TIME_10MS = '1') then
					count <= count + 1;
				else
					REDRAW 	<= '0';
				end if;
				
			end if;
	end process;
	
	ContinueButton : process (CLOCK, RESET_N)
	variable pressed : boolean := FALSE;
	begin
		if RESET_N = '0' then
			continue <= '0';
			debounce_state <= IDLE;
		elsif rising_edge(CLOCK) then
			case (debounce_state) is
				when IDLE =>
					if(BUTTON1 = '0') then
						debounce_state <= BUTTONPRESS;
						continue <= '1';	
					end if;

				when BUTTONPRESS =>
					continue <= '0';
					debounce_state <= WAITRELEASE;
				
				when WAITRELEASE =>
					if BUTTON1 = '1' then 
						debounce_state <= IDLE;
					end if;
				
			end case;
		end if;
	
	end process;
	
	NextstepButton : process (CLOCK, RESET_N)
	variable pressed : boolean := FALSE;
	begin
		if RESET_N = '0' then
			nextstep <= '0';
			debounce_state3 <= IDLE;
		elsif rising_edge(CLOCK) then
			case (debounce_state3) is
				when IDLE =>					
					if BUTTON2 = '0' then
						debounce_state3 <= BUTTONPRESS;
						nextstep <= '1';
					end if;
				
				when BUTTONPRESS =>
					nextstep <= '0';
					debounce_state3 <= WAITRELEASE;
				
				when WAITRELEASE =>
					if BUTTON2 = '1' then 
						debounce_state3 <= IDLE;
					end if;
				
			end case;
		end if;
	
	end process;
	
	solfind_success <= leftmost_ack and leftmost_success and rightmost_ack and rightmost_success;
	solfind_fail	<=	leftmost_ack and rightmost_ack and (not(leftmost_success) or not(rightmost_success));
	
	LogicSolve	: process (CLOCK, RESET_N)
	begin
		if RESET_N='0' then
			logic_solve_state <= IDLE;
			SET_LINE <= '0';
			intersect_req <= '0';
			
		elsif rising_edge(CLOCK) then
			case (logic_solve_state) is
				when IDLE =>
					if(logic_solve_req ='1' or probe_solve_req='1') then					
						intersect_req 		<= '0';						
						SET_LINE				<= '0';
						QUERY_LINE.index 	<= 0;
						QUERY_LINE.rowcol	<= ROW;
						logic_solve_state <= FINDMAXLINE;
						MAX_JOB_REQ 		<= '1';
					end if;
					
				when FINDMAXLINE =>
					MAX_JOB_REQ <= '0';
					SET_LINE <='0';
					if (MAX_JOB_ACK = '1') then
						if MAX_JOB_RESULT.inactive_jobs = BOARD_COLUMNS+BOARD_ROWS then
							-- nessun job attivo
							logic_solve_state <= IDLE;
							logic_solve_ack <= '1';
						else
							QUERY_LINE.index  <= MAX_JOB_RESULT.index;
							QUERY_LINE.rowcol <= MAX_JOB_RESULT.rowcol;
							logic_solve_state <= FETCH;
						end if;
					end if;
					
				when FETCH =>
					if continue = '1' or not(STEP_I='1') then
						line_input 			<= LINE_CONTENT;
						help_input 			<= HELP_LINE_CONTENT;
						logic_solve_state	<= WAITFORSOL;
						intersect_req 		<= '1';
					end if;
					
				when WAITFORSOL =>
					if intersect_ack='1' then					
						if intersect_success='1' then
							SET_LINE <= '1';
							SET_LINE_TYPE <= MAX_JOB_RESULT.rowcol;
							SET_LINE_INDEX <= MAX_JOB_RESULT.index;
							for i in 0 to BOARD_COLUMNS - 1 loop
								SET_LINE_CONTENT(i) <= intersect_output(i);
							end loop;
						else	
							SET_LINE <='0';
						end if;
						intersect_req <='0';
						logic_solve_state <= FINDMAXLINE;
						MAX_JOB_REQ 		<= '1';
					else
						SET_LINE<='0';
						intersect_req <='0';
					end if;
				when others =>
					intersect_req <= '0';
					SET_LINE<='0';
					logic_solve_state <= FINDMAXLINE;
					MAX_JOB_REQ 		<= '1';	
			end case;
		end if;
	end process;

	Intersect : process (CLOCK, RESET_N)
		variable lb 	: integer := 0;
		variable rb 	: integer := 0;
		variable j		: integer range 0 to BOARD_COLUMNS := 0;
		variable lgap 	: boolean := TRUE;
		variable rgap	: boolean := TRUE;
		variable help	: help_type; 		
		variable help_length : integer;
		variable left_end : boolean := FALSE;
		variable right_end: boolean := FALSE;
		variable left_succ: boolean := FALSE;
		variable right_succ:boolean := FALSE;
	begin		
		
		if RESET_N = '0' then
			intersect_state <= IDLE;
			intersect_ack <= '0';
			intersect_success <= '0';
			
		
		elsif rising_edge(CLOCK) then
		
			case ( intersect_state ) is
			
				when IDLE =>
				
					if intersect_req = '1' then

						help := help_input;
						help_length := GET_LENGTH(help_input);
						lb := 0;
						rb := 0;
						j := 0;
						lgap := TRUE;
						rgap := TRUE;
						
						left_end := FALSE;
						left_succ:= FALSE;
						right_end:= FALSE;
						right_succ:=FALSE;
						
						
						intersect_ack <= '0';
						--	invio richieste right/left 
						leftmost_req <= '1';
						rightmost_req <= '1';
						
						intersect_state <= WAITFORSOL;										
					end if;
					
					if intersect_ack = '1' then
						intersect_ack <= '0';
						intersect_success <= '0';
					end if;
				
				when WAITFORSOL =>
					
					if leftmost_ack = '1' and rightmost_ack = '0' then
						if not(right_end) then
							--salvo stato left
							left_end := TRUE;
							if leftmost_success = '1' then
								left_succ := TRUE;
							else
								left_succ := FALSE;
							end if;
							 
						else							
							if right_succ and leftmost_success = '1' then
								--continua
								intersect_state <= COMPUTING;
							else
								intersect_state <= IDLE;
								intersect_ack <= '1';
								intersect_success <= '0';
							end if;							
						end if;
					elsif rightmost_ack = '1' and leftmost_ack = '0' then
						if not(left_end) then
							--salvo stato right
							right_end := TRUE;
							if rightmost_success = '1' then
								right_succ := TRUE;
							else
								right_succ := FALSE;
							end if;
						else
							if left_succ and rightmost_success = '1' then
								--continua
								intersect_state <= COMPUTING;
							else
								intersect_state <= IDLE;
								intersect_ack <= '1';
								intersect_success <= '0';
							end if;
						end if;					
					elsif solfind_success = '1' then
						-- entrambe le soluzioni sono arrivate
						intersect_state <= COMPUTING;
					elsif solfind_fail = '1' then
						intersect_state <= IDLE;
						intersect_ack	<= '1';
						intersect_success <= '0';
					else
						--aggiungere caso per fallimento
						leftmost_req <= '0';
						rightmost_req <= '0';					
					end if;				
				
				when COMPUTING =>
									
					if j < BOARD_COLUMNS then 
					-- for loop
						
						if not(lgap) and leftmost_pos(lb) + help(lb) = j then
							lgap := TRUE;
							lb := lb + 1;
						end if;
						
						if lgap and lb < help_length and leftmost_pos(lb) = j then
							lgap := FALSE;
						end if;						
						
						if not(rgap) and rightmost_pos(rb) + 1 = j then
							rgap := TRUE;
							rb := rb + 1;
						end if;
						
						if rgap and rb < help_length and rightmost_pos(rb) - help(rb) + 1 = j then
							rgap := FALSE;
						end if;
						
						if lgap = rgap and lb = rb then
							if lgap then
								intersect_output(j) <= MARKED;
							else 
								intersect_output(j) <= FULL;
							end if;
						else
							intersect_output(j) <= EMPTY;
						end if;			

						j := j + 1;
					else
					-- fine for
						intersect_state 	<= IDLE;
						intersect_ack 		<= '1';	
						intersect_success <= '1';
					end if;				
			end case;
		end if;
		
	end process;

		
	GetLeftMostSol	  : process(CLOCK, RESET_N)
		variable j					: integer range -1 to BOARD_COLUMNS := 0;	
		variable b					: integer range -1 to BOARD_COLUMNS := 0;
		variable backtracking	: boolean;
		variable cov				: help_type;
		variable help				: help_type; 
		variable linea				: linea_type;
		variable help_length		: integer;
		begin
	
			if(RESET_N = '0') then	
				leftmost_state <= IDLE;
				leftmost_substate <= SEQ;
				leftmost_ack <= '0';
				leftmost_success <= '0';
				b := 0;
				j := 0;
				backtracking:= FALSE;
				for i in 0 to (BOARD_COLUMNS/2)-1 loop
					leftmost_pos(i) <= -1;
				end loop;
			
			elsif( rising_edge(CLOCK) ) then
				
				if ((nextstep = '1' or leftmost_req = '1' or leftmost_ack = '1') and STEP_LR='1') or not(STEP_LR='1') then
				
				case ( leftmost_state ) is
				
					when IDLE =>
						if leftmost_req = '1' then -- arrivata richiesta, preparo dati
							leftmost_state <= NEWBLOCK;
							leftmost_substate <= SEQ;
							leftmost_ack <= '0';
							leftmost_success <= '0';
								
							--linea := GET_LINE(board, line_index, line_type);
							--help  := GET_HELP(help_boards, line_index, line_type);								
							linea := line_input;
							help := help_input;
							help_length := GET_LENGTH(help_input);
							backtracking:= FALSE;
							b := 0;
							j := 0;
							for i in 0 to (BOARD_COLUMNS/2)-1 loop
								leftmost_pos(i) <= -1;
							end loop;
							--altre inizializzazioni qui
						end if;
						
						if leftmost_ack = '1' then
							leftmost_success <= '0';
							leftmost_ack <= '0';
						end if;							
						
					when NEWBLOCK =>
						
						if b >= help_length then
							if (b = 0) then 
								j := 0;
							end if;
							b := b - 1;
							leftmost_state <= CHECKREST;
						else
						
							if b = 0 then
								leftmost_pos(b) <= 0;
							else
								leftmost_pos(b) <= j + 1;
							end if;
						
							if j = BOARD_COLUMNS - 1 then
								--fail
								leftmost_success <= '0'; -- non necessario (inizializzato a zero)
								leftmost_state <= HALT;
							else
								leftmost_state <= PLACEBLOCK;
							end if;
						end if;
				
					when PLACEBLOCK =>				
						case (leftmost_substate) is
						
						when SEQ =>
						
							if linea(leftmost_pos(b)) = MARKED then
								--loop
								leftmost_substate <= LOOPING_1;
								leftmost_pos(b) <= leftmost_pos(b) + 1;
							else 
								-- non devo fare il loop iniziale, proseguo
								j := leftmost_pos(b);
								if linea(j) /= FULL then
									cov(b) := -1;
								else
									cov(b) := j;
								end if;
								
								j := j + 1;
								-- inizia ciclo for
								leftmost_substate <= LOOPING_2;
								
							end if;
							
						when LOOPING_1 =>
							-- while 
							if leftmost_pos(b) > BOARD_COLUMNS -1 then
							-- raggiunta fine linea, fallimento
								leftmost_success <= '0';
								leftmost_state <= HALT;
								leftmost_substate <= SEQ;
							
							elsif linea(leftmost_pos(b)) = MARKED then								
								--continua loop
								leftmost_pos(b) <= leftmost_pos(b) + 1;
							else
								-- fine loop
								leftmost_state <= PLACEBLOCK;
								leftmost_substate <= SEQ;
							end if;
						
						when LOOPING_2 =>
							-- for
							if not(j - leftmost_pos(b) < help(b)) then
								-- fine loop
								leftmost_state <= FINALSPACE;
								leftmost_substate <= SEQ;
							else
							
								if j >= BOARD_COLUMNS then
									-- fail
									leftmost_success <= '0';
									leftmost_state <= HALT;
									leftmost_substate <= SEQ;
								else								
									if linea(j) = MARKED then								
										if cov(b) = -1 then
											leftmost_pos(b) <= j;
											leftmost_state <= PLACEBLOCK;
											leftmost_substate <= SEQ;
										else
											leftmost_state <= BACKTRACK;
											leftmost_substate <= SEQ;
										end if;
									else									
									-- update cov(b)
										if cov(b) = -1 and linea(j) = FULL then
											cov(b) := j;
										end if;
										-- update j & continua loop
										j := j + 1;
									end if;
								end if;
							
							end if;
						
						end case;		
				
					when FINALSPACE =>
						if j < BOARD_COLUMNS and linea(j) = FULL then 
							--if linea(j) = FULL then
							-- while
							if cov(b) = leftmost_pos(b) then
								--backtrack
								leftmost_state <= BACKTRACK;
								leftmost_substate <= SEQ;
							else				
								-- primo loop
								leftmost_pos(b) <= leftmost_pos(b) + 1;									
								if cov(b) = -1 and linea(j) = FULL then
									cov(b) := j;
								end if;
								j := j + 1;																	
								leftmost_state <= FINALSPACE; -- loop, superfluo ma lo lascio
							end if;	
						else
							--prosegue
							if backtracking and cov(b) = -1 then
								backtracking := FALSE;
								leftmost_state <= ADVANCEBLOCK;
								leftmost_substate <= SEQ;																	
							elsif j >= BOARD_COLUMNS and b < help_length - 1 then
								-- fail
								leftmost_success <= '0';
								leftmost_state <= HALT;
								leftmost_substate <= SEQ;
							else
								b := b + 1;
								backtracking := FALSE;
								leftmost_state <= NEWBLOCK;
								leftmost_substate <= SEQ;
							end if;	
						end if;
					
				
					when CHECKREST =>					
						case (leftmost_substate) is 						
						when SEQ =>
							
							if j < BOARD_COLUMNS then
								--loop
								if linea(j) = FULL then
									j := leftmost_pos(b) + help(b);
									leftmost_state <= ADVANCEBLOCK;
									leftmost_substate <= SEQ;
								else
									j := j + 1;
									leftmost_state <= CHECKREST;
								end if;				
							else 
								--success
								leftmost_success <= '1';
								leftmost_state <= HALT;
								leftmost_substate <= SEQ;							
							end if;
						when others =>
							leftmost_substate <= SEQ;						
						end case;
				
					when BACKTRACK =>				
						b := b - 1;						
						if b < 0 then 
							--fail
							leftmost_success <= '0';
							leftmost_state <= HALT;
							leftmost_substate <= SEQ;
						else
							j := leftmost_pos(b) + help(b);
							leftmost_state <= ADVANCEBLOCK;
						end if;						
				
					when ADVANCEBLOCK =>
											
							if cov(b) < 0 or leftmost_pos(b) < cov(b) then
								--loop
								if linea(j) = MARKED then
									if cov(b) > 0 then
										leftmost_state <= BACKTRACK;
										leftmost_substate <= SEQ;
									else
										leftmost_pos(b) <= j + 1;
										backtracking := TRUE;
										leftmost_state <= PLACEBLOCK;
										leftmost_substate <= SEQ;
									end if;
								else
									leftmost_pos(b) <= leftmost_pos(b) + 1;
								
									if linea(j) = FULL then
										j := j + 1;
										if cov(b) = -1 then
											cov(b) := j - 1;
										end if;
										leftmost_state <= FINALSPACE;
										leftmost_substate <= SEQ;
									elsif j >= BOARD_COLUMNS then
										--fail 
										leftmost_success <= '0';
										leftmost_state <= HALT;
										leftmost_substate <= SEQ;							
									else
										j := j + 1;
									end if;
									
									
									-- si ripete il loop
								end if;
							else	
								leftmost_state <= BACKTRACK;
								leftmost_substate <= SEQ;
							end if;
				
					when HALT =>						
						leftmost_ack <= '1';
						leftmost_state <= IDLE;			
				end case;	
				end if; --nextstep
			end if; --clock
	end process;
 	
	GetRightMostSol	  : process(CLOCK, RESET_N)
		variable j					: integer range -1 to BOARD_COLUMNS;	
		variable b					: integer range -1 to BOARD_COLUMNS := 0;
		variable backtracking	: boolean;
		variable cov				: help_type;
		variable help				: help_type; 
		variable linea				: linea_type;
		variable help_length		: integer;
		variable temp_pos			: help_type := (others => -1);
		begin
	
			if(RESET_N = '0') then	
				rightmost_state <= IDLE;
				rightmost_substate <= SEQ;
				rightmost_ack <= '0';
				rightmost_success <= '0';
				b := 0;
				backtracking:= FALSE;	
				
				
				rightmost_pos<= (others => -1);
				temp_pos:= (others => -1);
				
				
			elsif( rising_edge(CLOCK) ) then
				if ((nextstep = '1' or rightmost_req = '1' or rightmost_ack = '1') and STEP_LR='1') or not(STEP_LR='1') then
				case ( rightmost_state ) is
				
					when IDLE =>
						if rightmost_req = '1' then -- arrivata richiesta, preparo dati
							rightmost_state <= NEWBLOCK;
							rightmost_substate <= SEQ;
							rightmost_ack <= '0';
							rightmost_success <= '0';
							
							
--							linea := GET_LINE(board, line_index, line_type);
--							help  := GET_HELP(help_boards, line_index, line_type);		
							linea := line_input;
							help 	:= help_input;
							help_length := GET_LENGTH(help_input);
							backtracking:= FALSE;
							b := help_length-1;
							for i in 0 to (BOARD_COLUMNS/2)-1 loop
								rightmost_pos(i) <= -1;
								temp_pos(i) := -1;
							end loop;
						
						end if;
						
						if rightmost_ack = '1' then
							rightmost_ack <= '0';
							rightmost_success <= '0';
						end if;
						
					when NEWBLOCK =>
						
						if b < 0 then
							if (b = help_length-1) then 
								j := BOARD_COLUMNS-1;
							end if;
							b := b + 1;
							rightmost_state <= CHECKREST;
						else
						
							if b = help_length-1 then
								--rightmost_pos(b) <= BOARD_COLUMNS-1;
								temp_pos(b) := BOARD_COLUMNS-1;
							else
								temp_pos(b) := j - 1;								
							end if;
						
							if temp_pos(b) - help(b) +1 < 0 then
								--fail
								rightmost_success <= '0'; -- non necessario (inizializzato a zero)
								rightmost_state <= HALT;
							else
								rightmost_state <= PLACEBLOCK;
							end if;
						end if;						
				
					when PLACEBLOCK =>				
						case (rightmost_substate) is
						
						when SEQ =>
						
							if linea(temp_pos(b)) = MARKED then
								--loop
								rightmost_substate <= LOOPING_1;
								temp_pos(b) := temp_pos(b) - 1;
							else 
								-- non devo fare il loop iniziale, proseguo
								j := temp_pos(b);
								if linea(j) /= FULL then
									cov(b) := -1;
								else
									cov(b) := j;
								end if;
								
								j := j - 1;
								-- inizia ciclo for
								rightmost_substate <= LOOPING_2;
								
							end if;
							
						when LOOPING_1 =>
							-- while 
							-- while 
							if temp_pos(b) < 0 then
							-- raggiunta fine linea, fallimento
								rightmost_success <= '0';
								rightmost_state <= HALT;
								rightmost_substate <= SEQ;
							
							elsif linea(temp_pos(b)) = MARKED then								
								--continua loop
								temp_pos(b) := temp_pos(b) - 1;
							else
								-- fine loop
								rightmost_state <= PLACEBLOCK;
								rightmost_substate <= SEQ;
							end if;
						
						when LOOPING_2 =>
							-- for
							if not(temp_pos(b) - j < help(b)) then
								-- fine loop
								rightmost_state <= FINALSPACE;
								rightmost_substate <= SEQ;
							else
							
								if j < 0 then
									-- fail
									rightmost_success <= '0';
									rightmost_state <= HALT;
									rightmost_substate <= SEQ;
								else								
									if linea(j) = MARKED then								
										if cov(b) = -1 then
											temp_pos(b) := j;
											rightmost_state <= PLACEBLOCK;
											rightmost_substate <= SEQ;
										else
											rightmost_state <= BACKTRACK;
											rightmost_substate <= SEQ;
										end if;
									else									
									-- update cov(b)
										if cov(b) = -1 and linea(j) = FULL then
											cov(b) := j;
										end if;
										-- update j & continua loop
										j := j - 1;
									end if;
								end if;
							
							end if;
						
						end case;		
				
					when FINALSPACE =>
						if j >=0 and linea(j) = FULL then 
							--if linea(j) = FULL then
							-- while
							if cov(b) = temp_pos(b) then
								--backtrack
								rightmost_state <= BACKTRACK;
								rightmost_substate <= SEQ;
							else				
								-- primo loop
								temp_pos(b) := temp_pos(b) - 1;									
								if cov(b) = -1 and linea(j) = FULL then
									cov(b) := j;
								end if;
								j := j - 1;																	
								rightmost_state <= FINALSPACE; -- loop, superfluo ma lo lascio
							end if;	
						else
							--prosegue
							if backtracking and cov(b) = -1 then
								backtracking := FALSE;
								rightmost_state <= ADVANCEBLOCK;
								rightmost_substate <= SEQ;																	
							elsif j <0 and b >0 then
								-- fail
								rightmost_success <= '0';
								rightmost_state <= HALT;
								rightmost_substate <= SEQ;
							else
								b := b - 1;
								backtracking := FALSE;
								rightmost_state <= NEWBLOCK;
								rightmost_substate <= SEQ;
							end if;	
						end if;
					
				
					when CHECKREST =>					
						case (rightmost_substate) is 						
						when SEQ =>
							
							if j >=0 then
								--loop
								if linea(j) = FULL then
									j := temp_pos(b) - help(b);
									rightmost_state <= ADVANCEBLOCK;
									rightmost_substate <= SEQ;
								else
									j := j - 1;
									rightmost_state <= CHECKREST;
								end if;				
							else 
								--success
								rightmost_success <= '1';
								rightmost_state <= HALT;
								rightmost_substate <= SEQ;							
							end if;
						when others =>
							rightmost_substate<= SEQ;						
						end case;
				
					when BACKTRACK =>				
						b := b + 1;						
						if b > help_length-1 then 
							--fail
							rightmost_success <= '0';
							rightmost_state <= HALT;
							rightmost_substate <= SEQ;
						else
							j := temp_pos(b) - help(b);
							rightmost_state <= ADVANCEBLOCK;
						end if;						
				
					when ADVANCEBLOCK =>
											
							if cov(b) < 0 or temp_pos(b) > cov(b) then
								--loop
								if linea(j) = MARKED then
									if cov(b) > 0 then
										rightmost_state <= BACKTRACK;
										rightmost_substate <= SEQ;
									else
										temp_pos(b) := j - 1;
										backtracking := TRUE;
										rightmost_state <= PLACEBLOCK;
										rightmost_substate <= SEQ;
									end if;
								else
									temp_pos(b) := temp_pos(b) - 1;
								
									if linea(j) = FULL then
										j := j - 1;
										if cov(b) = -1 then
											cov(b) := j + 1;
										end if;
										rightmost_state <= FINALSPACE;
										rightmost_substate <= SEQ;
									elsif j < 0 then
										--fail 
										rightmost_success <= '0';
										rightmost_state <= HALT;
										rightmost_substate <= SEQ;							
									else
										j := j - 1;
									end if;
									
									
									-- si ripete il loop
								end if;
							else	
								rightmost_state <= BACKTRACK;
								rightmost_substate <= SEQ;
							end if;
				
					when HALT =>			
						rightmost_pos <= temp_pos;
						rightmost_ack <= '1';
						rightmost_state <= IDLE;					
				end case;
				end if; --nextstep
			end if; --clock
	end process;
	
	

            
end architecture;
