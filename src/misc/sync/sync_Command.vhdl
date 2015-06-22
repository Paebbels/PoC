-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
-- 
-- =============================================================================
-- Authors:					Patrick Lehmann
--									Steffen Koehler
--
-- Module:					Synchronizes a command signal across clock-domain boundaries
--
-- Description:
-- ------------------------------------
--		This module synchronizes a vector of bits from clock-domain 'Clock1' to
--		clock-domain 'Clock2'. The clock-domain boundary crossing is done by a
--		change comparator, a T-FF, two synchronizer D-FFs and a reconstructive
--		XOR indicating a value change on the input. This changed signal is used
--		to capture the input for the new output. A busy flag is additionally
--		calculated for the input clock-domain. The output has strobe character
--		and is reset to it's INIT value after one clock cycle.
-- 
--		CONSTRAINTS:
--			General:
--				This module uses sub modules which need to be constrained. Please
--				attend to the notes of the instantiated sub modules.
-- 
-- License:
-- =============================================================================
-- Copyright 2007-2015 Technische Universitaet Dresden - Germany
--										 Chair for VLSI-Design, Diagnostics and Architecture
-- 
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
-- 
--		http://www.apache.org/licenses/LICENSE-2.0
-- 
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- =============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;


entity sync_Command IS
  generic (
	  BITS								: POSITIVE					:= 8;											-- number of bit to be synchronized
		INIT								: STD_LOGIC_VECTOR	:= x"00000000"						-- 
	);
  PORT (
		Clock1							: in	STD_LOGIC;															-- <Clock>	input clock
		Clock2							: in	STD_LOGIC;															-- <Clock>	output clock
		Input								: in	STD_LOGIC_VECTOR(BITS - 1 downto 0);		-- @Clock1:	input vector
		Output							: out STD_LOGIC_VECTOR(BITS - 1 downto 0);		-- @Clock2:	output vector
		Busy								: out	STD_LOGIC;															-- @Clock1:	busy bit 
		Changed							: out	STD_LOGIC																-- @Clock2:	changed bit
	);
end;


architecture rtl OF sync_Command is
	attribute SHREG_EXTRACT				: STRING;
	
	constant INIT_I								: STD_LOGIC_VECTOR												:= descend(INIT)(BITS - 1 downto 0);
	
	signal D0											: STD_LOGIC																:= '0';
	signal D1											: STD_LOGIC_VECTOR(BITS - 1 downto 0)			:= INIT_I;
	signal T2											: STD_LOGIC																:= '0';
	signal D3											: STD_LOGIC																:= '0';
	signal D4											: STD_LOGIC																:= '0';
	signal D5											: STD_LOGIC_VECTOR(BITS - 1 downto 0)			:= INIT_I;

	signal IsCommand_Clk1					: STD_LOGIC;
	signal Changed_Clk1						: STD_LOGIC;
	signal Changed_Clk2						: STD_LOGIC;
	signal Busy_i									: STD_LOGIC;
	
	-- Prevent XST from translating two FFs into SRL plus FF
	attribute SHREG_EXTRACT of D0	: signal IS "NO";
	attribute SHREG_EXTRACT of T2	: signal IS "NO";
	attribute SHREG_EXTRACT of D3	: signal IS "NO";
	attribute SHREG_EXTRACT of D4	: signal IS "NO";
	attribute SHREG_EXTRACT of D5	: signal IS "NO";

	signal syncClk1_In		: STD_LOGIC;
	signal syncClk1_Out		: STD_LOGIC;
	signal syncClk2_In		: STD_LOGIC;
	signal syncClk2_Out		: STD_LOGIC;

begin

	-- input D-FF @Clock1 -> changed detection
	process(Clock1)
	begin
		if rising_edge(Clock1) then
			if (Busy_i = '0') then
				D0	<= IsCommand_Clk1;				-- delay detected IsCommand signal for rising edge detection; gated by busy flag
				D1	<= Input;									
				T2	<= T2 xor Changed_Clk1;		-- toggle T2 if input vector has changed
			end if;
		end if;
	end process;
	
	-- D-FF for level change detection (both edges)
	process(Clock2)
	begin
		if rising_edge(Clock2) then
			D3		<= syncClk2_Out;
			D4		<= Changed_Clk2;
			
			if (D4 = '1') then
				D5	<= INIT_I;
			elsif (Changed_Clk2 = '1') then
				D5	<= D1;
			end if;
		end if;
	end process;

	-- assign syncClk*_In signals
	syncClk2_In		<= T2;
	syncClk1_In		<= D3;
	
	IsCommand_Clk1	<= to_sl(Input /= INIT_I);			-- input command detection
	Changed_Clk1		<= not D0 and IsCommand_Clk1;		-- input rising edge detection
	Changed_Clk2		<= syncClk2_Out xor D3;					-- level change detection; restore strobe signal from flag
	Busy_i					<= T2 xor syncClk1_Out;					-- calculate busy signal
	
	-- output signals
	Output				<= D5;
	Busy					<= Busy_i;
	Changed				<= D4;
		
	syncClk2 : entity PoC.sync_Flag
		generic map (
			BITS				=> 1							-- number of bit to be synchronized
		)
		port map (
			Clock				=> Clock2,				-- <Clock>	output clock domain
			Input(0)		=> syncClk2_In,		-- @async:	input bits
			Output(0)		=> syncClk2_Out		-- @Clock:	output bits
		);
	
	syncClk1 : entity PoC.sync_Flag
		generic map (
			BITS				=> 1							-- number of bit to be synchronized
		)
		port map (
			Clock				=> Clock1,				-- <Clock>	output clock domain
			Input(0)		=> syncClk1_In,		-- @async:	input bits
			Output(0)		=> syncClk1_Out		-- @Clock:	output bits
		);
end;