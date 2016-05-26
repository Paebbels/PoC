-- EMACS settings: -*-  tab-width: 2; indent-tabs-mode: t -*-
-- vim: tabstop=2:shiftwidth=2:noexpandtab
-- kate: tab-width 2; replace-tabs off; indent-width 2;
--
-- ============================================================================
-- Authors:				 	Patrick Lehmann
--
-- Module:				 	A generic buffer module for the PoC.Stream protocol.
--
-- Description:
-- ------------------------------------
--		This module implements a generic buffer (FIFO) for the PoC.Stream protocol.
--		It is generic in DATA_BITS and in META_BITS as well as in FIFO depths for
--		data and meta information.
--
-- License:
-- ============================================================================
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
-- WITHOUT WARRANTIES OR CONDITIONS of ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- ============================================================================

library IEEE;
use			IEEE.STD_LOGIC_1164.all;
use			IEEE.NUMERIC_STD.all;

library PoC;
use			PoC.utils.all;
use			PoC.vectors.all;
use			PoC.strings.all;
use			PoC.stream.all;


entity stream_Source is
	generic (
		TESTCASES												: T_SIM_STREAM_FRAMEGROUP_VECTOR_8
	);
	port (
		Clock														: in	STD_LOGIC;
		Reset														: in	STD_LOGIC;
		-- Control interface
		Enable													: in	STD_LOGIC;
		-- OUT Port
		Out_Valid												: out	STD_LOGIC;
		Out_Data												: out	T_SLV_8;
		Out_SOF													: out	STD_LOGIC;
		Out_EOF													: out	STD_LOGIC;
		Out_Ack													: in	STD_LOGIC
	);
end entity;


architecture rtl of stream_Source is
	constant MAX_CYCLES											: NATURAL																			:= 10 * 1000;
	constant MAX_ERRORS											: NATURAL																			:=				50;

	-- dummy signals for iSIM
	signal FrameGroupNumber_us		: UNSIGNED(log2ceilnz(TESTCASES'length) - 1 downto 0)		:= (others => '0');
begin

	process
		variable Cycles							: NATURAL			:= 0;
		variable Errors							: NATURAL			:= 0;

		variable FrameGroupNumber		: NATURAL			:= 0;

		variable WordIndex					: NATURAL			:= 0;
		variable CurFG							: T_SIM_STREAM_FRAMEGROUP_8;

	begin
		-- set interface to default values
		Out_Valid					<= '0';
		Out_Data					<= (others => 'U');
		Out_SOF						<= '0';
		Out_EOF						<= '0';

		-- wait for global enable signal
		wait until (Enable = '1');

		-- synchronize to clock
		wait until rising_edge(Clock);

		-- for each testcase in list
		for TestcaseIndex in 0 to TESTCASES'length - 1 loop
			-- initialize per loop
			Cycles	:= 0;
			Errors	:= 0;
			CurFG		:= TESTCASES(TestcaseIndex);

			-- continue with next frame if current is disabled
			assert FALSE report "active=" & to_string(CurFG.Active) severity WARNING;
			next when CurFG.Active = FALSE;

			-- write dummy signals for iSIM
			FrameGroupNumber			:= TestcaseIndex;
			FrameGroupNumber_us		<= to_unsigned(FrameGroupNumber, FrameGroupNumber_us'length);

			-- PrePause
			for i in 1 to CurFG.PrePause loop
				wait until rising_edge(Clock);
			end LOOP;

			WordIndex							:= 0;

			-- infinite loop
			loop
				-- check for to many simulation cycles
				assert (Cycles < MAX_CYCLES) report "MAX_CYCLES reached:  framegroup=" & INTEGER'image(to_integer(FrameGroupNumber_us)) severity FAILURE;
--				ASSERT (Errors < MAX_ERRORS) report "MAX_ERRORS reached" severity FAILURE;
				Cycles := Cycles + 1;

				wait until rising_edge(Clock);
				-- write frame data to interface
				Out_Valid					<= CurFG.Data(WordIndex).Valid;
				Out_Data					<= CurFG.Data(WordIndex).Data;
				Out_SOF						<= CurFG.Data(WordIndex).SOF;
				Out_EOF						<= CurFG.Data(WordIndex).EOF;

				wait until falling_edge(Clock);
				-- go to next word if interface counterpart has accepted the current word
				if (Out_Ack	 = '1') then
					WordIndex := WordIndex + 1;
				end if;

				-- check if framegroup end is reached => exit LOOP
				assert FALSE report "WordIndex=" & INTEGER'image(WordIndex) severity WARNING;
				exit when ((WordIndex /= 0) AND (CurFG.Data(WordIndex - 1).EOFG = TRUE));
			end loop;

			-- PostPause
			for i in 1 to CurFG.PostPause loop
				wait until rising_edge(Clock);
			end loop;

			assert FALSE report "new round" severity WARNING;
		end loop;

		-- set interface to default values
		wait until rising_edge(Clock);
		Out_Valid					<= '0';
		Out_Data					<= (others => 'U');
		Out_SOF						<= '0';
		Out_EOF						<= '0';
	end process;

end architecture;
