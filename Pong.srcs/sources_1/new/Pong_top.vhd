-------------------------------------------
-- Gaetan Blankers
--
-- switch 15 => left paddle movement
-- switch 8 => Left paddle CPU
-- switch 7 => Right paddle CPU
-- up/down button => right paddle movement
-- middle button => reset
-------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Pong_top is

    generic (
        G_Hpulse 	:	INTEGER := 112;    	    --horiztonal sync pulse pixels
        G_Hbp	 	:	INTEGER := 248;		    --horiztonal back porch pixels
        G_Hpixels	:	INTEGER := 1280;		--horiztonal display pixels
        G_Hfp	 	:	INTEGER := 48;		    --horiztonal front porch pixels   

        G_Vpulse 	:	INTEGER := 3;			--vertical sync pulse rows
        G_Vbp	 	:	INTEGER := 38;			--vertical back porch rows
        G_Vpixels	:	INTEGER := 1024;		--vertical display rows
        G_Vfp	 	:	INTEGER := 1;			--vertical front porch rows
        
        G_Active    :   std_logic := '1'
    );

    Port (
        CLK100MHZ: in std_logic;                    -- System clock [clock]
        RES: in std_logic;                          -- Asynchronous reset [button]

        R_UP: in std_logic;                         -- Right paddle movement up [button]
        R_DOWN: in std_logic;                       -- Right paddle movement down [button]
        L_MOVE: in std_logic;                       -- Left paddle movement [switch]
        R_CPU: in std_logic;                        -- Enable cpu right paddle [switch]
        L_CPU: in std_logic;                        -- Enable cpu left paddle [switch]

        AN: out std_logic_vector (3 downto 0);      -- Anode active 7 segment displays [2 most left and 2 most right]
        O: out std_logic_vector (6 downto 0);       -- Output 7 segment displays
        SEG_OFF: out std_logic_vector (3 downto 0); -- Anode not active 7 segment displays [Middle 4]

        VGA_R: out std_logic_vector (3 downto 0);   -- Red signal VGA
        VGA_G: out std_logic_vector (3 downto 0);   -- Green signal VGA
        VGA_B: out std_logic_vector (3 downto 0);   -- Blue signal VGA
        VGA_HS: out std_logic;                      -- Horizontal sync VGA
        VGA_VS: out std_logic                       -- Vertical sync VGA
    );

end Pong_top;

architecture Behavioral of Pong_top is

    type tSegm is array(0 to 9) of std_logic_vector(6 downto 0); -- Array outputs 7 segment displays

    constant cSegm : tSegm := ("0000001", --0
                                "1001111", --1
                                "0010010", --2
                                "0000110", --3
                                "1001100", --4
                                "0100100", --5
                                "0100000", --6
                                "0001111", --7
                                "0000000", --8
                                "0000100"); --9 
    
    constant C_HPeriod	: integer := G_Hpulse + G_Hbp + G_Hpixels + G_Hfp;
    constant C_VPeriod	: integer := G_Vpulse + G_Vbp + G_Vpixels + G_Vfp;
    
    constant C_BorderWidth : integer := 10; 
    
    signal pixel_clk : std_logic;           -- VGA pixel clock 108MHz
    signal clk_200Hz : std_logic := '0';    -- Clock 7 segment displays
    signal clk_5MHz  : std_logic;           -- Reduced clock (clockip) for 7 segment clock
    signal clk_60hz  : std_logic;           -- New frame clock

    signal clk_count: integer := 12500;     -- 5MHz => 200Hz
    signal counter: integer := 0;

    signal segment_counter: integer;        
    
    signal HPixelCount : integer := 0;      -- Counter for horizontal pixels
    signal VPixelCount : integer := 0;      -- Counter for vertical pixels

    --Ball
    constant C_BallStartX : integer := 630;
    constant C_BallStartY : integer := 502;
    constant C_BallStartWidth : integer := 20;
    signal ballWidth : integer := 20;
    signal ballX : integer := C_BallStartX;     -- Coördinates left corner := Start coordinates
    signal ballY : integer := C_BallStartY;
    signal ballVelocityX : integer := 3;
    signal ballVelocityY : integer := 3;

    constant C_paddleWidth : integer := 10;
    constant C_playerPaddleSpeed : integer := 4;
    constant C_CPUPaddleSpeed : integer := 6;
    constant C_normalPaddleLength : integer := 200;

    --Left paddle
    signal L_paddleX : integer := 18; -- Coördinates left corner := Start coordinates
    signal L_paddleY : integer := 412;
    signal L_paddleLength : integer := 200;
    signal L_paddleSpeed : integer := 4;
    
    --Right paddle
    signal R_paddleX : integer := 1254; -- Coördinates left corner := Start coordinates
    signal R_paddleY : integer := 412;
    signal R_paddleLength : integer := 200;
    signal R_paddleSpeed : integer := 4;

    --Scores
    signal R_Score: integer := 0;
    signal L_Score: integer := 0;

    --Powerup
    signal timeToAppear : integer := 900;                       -- time until powerup appears : 15 sec
    signal timerAppear : integer := 0;
    signal timeActive : integer := 720;                         -- time powerup stays active : 12 sec
    signal timerActive : integer := 0;
    signal powerUpVisible : std_logic := '0';                   -- is powerup visible?
    signal powerUpActive : std_logic := '0';                    -- is powerup active?
    signal powerUpX : integer := 610;                           -- Coördinates left corner
    signal powerUpY : integer := 482;
    signal powerUpWidth : integer := 60; 
    signal powerUps : integer := 3;                             -- Amount of different powerups
    signal powerUpCounter : integer range 1 to 3:= 1;                       -- Counter to go through powerups
    signal powerUpNr : std_logic_vector(4 downto 0);    -- "00001" Ball size
                                                        -- "00010" Left Pallet size +
                                                        -- "00100" Right Pallet size +
                                                        -- "01000" Left Pallet size -
                                                        -- "10000" Right Pallet size -
    
    component clk_pixel
        Port(
            clk_in : in std_logic;
            clk_out : out std_logic;
            clk_out2: out std_logic;
            reset: in std_logic
        );
    end component;

begin

    clk_pixel_1: clk_pixel
    port map(
        clk_in => CLK100MHZ,
        clk_out => pixel_clk, -- 108 MHz
        clk_out2 => clk_5MHz,
        reset => RES
    );

    p_clkPrescale: process(clk_5MHz) -- Create 200Hz signal for 7 segment displays
    begin
        if rising_edge(clk_5Mhz) then
            if (counter >= clk_count) then
                counter <= 0;
                clk_200hz <= not clk_200hz;
            else 
                counter <= counter + 1;
            end if;
        end if;
    end process; 

    p_HSync: process(HPixelCount) -- VGA horizontal sync pulse
    begin
        if ((HPixelCount >= G_Hfp + G_Hpixels) and (HPixelCount <= G_Hfp + G_Hpulse + G_Hpixels)) then
            VGA_HS <= G_Active;
        else
            VGA_HS <= not G_Active;
        end if;
    end process;
  
    p_VSync: process(VPixelCount) -- VGA vertical sync pulse
    begin
        if ((VPixelCount >= G_Vfp + G_Vpixels) and (VPixelCount <= G_Vfp + G_Vpulse + G_Vpixels)) then
            VGA_VS <= G_Active;
        else
            VGA_VS <= not G_Active;
        end if;
    end process;

    p_Pixels: process(pixel_clk, RES) -- count pixels
    begin
        if (RES = '1') then
            HPixelCount <= 0;
            VPixelCount <= 0;
        elsif(rising_edge(pixel_clk)) then
            if(HPixelCount = C_HPeriod) then 
                HPixelCount <= 0;
                if (VPixelCount = C_VPeriod) then
                    VPixelCount <= 0;
                    clk_60hz <= G_active; -- New frame
                else
                    VPixelCount <= VPixelCount + 1;
                    clk_60hz <= not G_active; 
                end if;
            else
                HPixelCount <= HPixelCount + 1;
            end if;
        end if;
    end process;

    -- Right paddle movement + PowerUp + CPU 
    p_RPaddle: process(clk_60hz)
    begin
        if rising_edge(clk_60hz) then
            -- Movement + cpu
            if (R_CPU = '1') then -- CPU is active for right paddle
                R_paddleSpeed <= C_CPUPaddleSpeed; -- higher speed for CPU 

                -- Ball right side and above paddle => move right paddle up until it hits top border
                if (ballY <= R_PaddleY + R_PaddleLength /2 and ballX >= G_HPixels/2 and R_PaddleY >= C_BorderWidth) then
                    R_PaddleY <= R_PaddleY - R_paddleSpeed;

                -- Ball right side and under paddle => move right paddle down until it hits bottom border
                elsif (ballY >= R_PaddleY + R_PaddleLength /2 and ballX >= G_HPixels/2 and R_PaddleY <= G_VPixels - (C_BorderWidth + R_PaddleLength)) then
                    R_PaddleY <= R_PaddleY + R_paddleSpeed;

                -- Ball other side => move paddle to middle 
                elsif (R_PaddleY <= G_Vpixels/2 - R_PaddleLength/2 and ballX <= G_HPixels/2) then
                    R_PaddleY <= R_PaddleY + (R_paddleSpeed - 2);
                elsif (R_PaddleY >= G_Vpixels/2 - R_PaddleLength/2 and ballX <= G_HPixels/2) then
                    R_PaddleY <= R_PaddleY - (R_paddleSpeed - 2);
                end if ;

            else  -- CPU isn't active
                R_paddleSpeed <= C_playerPaddleSpeed; -- lower speed for player 
                if (R_DOWN = '1' and R_PaddleY <= G_VPixels - (C_BorderWidth + R_PaddleLength)) then
                    R_PaddleY <= R_PaddleY + R_paddleSpeed; -- move paddle down until it hits bottom border
                elsif (R_UP = '1' and R_PaddleY >= C_BorderWidth) then
                    R_PaddleY <= R_PaddleY - R_paddleSpeed; -- move paddle up until it hits top border
                end if;
            end if ;

            -- PowerUp
            if (powerUpActive = '1' and powerUpNr(2) = '1') then 

                -- Make paddle bigger if it hasn't already
                if (R_paddleLength = C_normalPaddleLength) then
                    R_PaddleLength <= R_PaddleLength*2;
                end if;

            elsif (powerUpActive = '1' and powerUpNr(4) = '1') then

                -- Make paddle smaller if it hasn't already
                if (R_paddleLength = C_normalPaddleLength) then
                    R_PaddleLength <= R_PaddleLength/2;
                end if;

            else
                -- Normal length if powerup isn't active
                R_PaddleLength <= C_normalPaddleLength;
            end if;

        end if;
    end process;

    -- Left paddle movement + powerup + CPU
    p_LPaddle: process(clk_60hz)
    begin
        if rising_edge(clk_60hz) then
            -- movement + CPU
            if (L_CPU = '1') then -- CPU is active for left paddle
                L_paddleSpeed <= C_CPUPaddleSpeed; -- higher speed for CPU

                -- Ball left side and above paddle => move left paddle up until it hits top border
                if (ballY <= L_PaddleY + L_PaddleLength /2 and ballX <= G_HPixels/2 and L_PaddleY >= C_BorderWidth) then
                    L_PaddleY <= L_PaddleY - L_paddleSpeed;

                -- Ball left side and under paddle => move left paddle down until it hits bottom border
                elsif (ballY >= L_PaddleY + L_PaddleLength /2 and ballX <= G_HPixels/2 and L_PaddleY <= G_VPixels - (C_BorderWidth + L_PaddleLength)) then
                    L_PaddleY <= L_PaddleY + L_paddleSpeed;

                -- Ball other side => move paddle to middle 
                elsif (L_PaddleY <= G_Vpixels/2 - L_PaddleLength/2 and ballX >= G_HPixels/2) then
                    L_PaddleY <= L_PaddleY + (L_paddleSpeed - 2);
                elsif (L_PaddleY >= G_Vpixels/2 - L_PaddleLength/2 and ballX >= G_HPixels/2) then
                    L_PaddleY <= L_PaddleY - (L_paddleSpeed - 2);  
                end if ;

            else -- CPU isn't active 
                L_paddleSpeed <= C_playerPaddleSpeed; -- lower speed for player
                if (L_Move = '0' and L_PaddleY <= G_VPixels - (C_BorderWidth + L_PaddleLength)) then
                    L_PaddleY <= L_PaddleY + L_paddleSpeed; -- move paddle down until it hits bottom border
                elsif (L_Move = '1' and L_PaddleY >= C_BorderWidth) then
                    L_PaddleY <= L_PaddleY - L_paddleSpeed; -- move paddle up until it hits top border
                end if;

            end if ;

            -- Powerup
            if (powerUpActive = '1' and powerUpNr(1) = '1') then

                -- Make paddle bigger if it hasn't already
                if (L_paddleLength = C_normalPaddleLength) then
                    L_PaddleLength <= L_PaddleLength*2;
                end if;

            elsif (powerUpActive = '1' and powerUpNr(3) = '1') then

                -- Make paddle smaller if it hasn't already
                if (L_paddleLength = C_normalPaddleLength) then
                    L_PaddleLength <= L_PaddleLength/2;
                end if;

            else
                -- Normal length if powerup isn't active
                L_PaddleLength <= C_normalPaddleLength;
            end if;

        end if;
    end process;

    p_Ball: process(clk_60hz, RES)
    begin
        if(RES = '1') then
            ballX <= C_BallStartX;
            ballY <= C_BallStartY;
            ballVelocityX <= 3;
            ballVelocityY <= 0;
            L_Score <= 0;
            R_Score <= 0;
            timerAppear <= 0;
            timerActive <= 0;
            powerUpVisible <= '0';
        elsif rising_edge(clk_60hz) then

            -- Ball Movement
            ballX <= ballX + ballVelocityX;
            ballY <= ballY + ballVelocityY;

            -- Powerup size
            if (powerUpActive = '1' and powerUpNr(0) = '1') then
                -- Make ball bigger if it hasn't already
                if (ballwidth = C_BallstartWidth) then
                    ballwidth <= ballwidth * 4;
                end if;

            else
                -- Normal ballsize if powerup isn't active
                ballwidth <= C_BallStartWidth;
            end if;
            
            -- Ball Hits

            -- Hit Left
            if (BallX <= L_PaddleX + C_Paddlewidth) then -- X pos where ball can hit paddle or border
                if(ballY <= L_PaddleY + L_PaddleLength and ballY >= L_PaddleY - ballwidth) then -- Ball between top and bottom of paddle?
                    if (ballVelocityX < 0) then 

                        if(BallY < L_PaddleY + L_PaddleLength/2) then -- Ball hits at top of paddle
                            -- Increase X Speed each 10 pixels closer to middle of paddle
                            -- + positive speed => ball moves right
                            ballVelocityX <= (ballY - L_paddleY)/10;
                            -- Increase Y Speed each 10 pixels closer to top of paddle
                            -- + Negative speed => ball moves up 
                            ballVelocityY <= ((L_PaddleLength/2) - (ballY - L_paddleY))/(-10);

                        elsif (BallY = L_PaddleY + L_PaddleLength/2) then -- Ball hits in middle of paddle
                            ballVelocityX <= 6;

                        else -- Ball at bottom of paddle
                            -- Increase X Speed each 10 pixels closer to middle of paddle
                            -- + positive speed => ball moves right
                            ballVelocityX <= ((L_paddleY + L_PaddleLength) - ballY)/10; 
                            -- Increase Y Speed each 10 pixels closer to top of paddle
                            -- + Positive speed => ball moves down
                            ballVelocityY <= (ballY - (L_paddleY + L_PaddleLength/2))/10;
                        end if;

                    end if ;
                else -- Goal => reset and R_score +1
                    ballX <= C_BallStartX;
                    BallY <= C_BallStartY;
                    ballVelocityX <= 3;
                    ballVelocityY <= 3;
                    R_Score <= R_Score + 1;
                    timerAppear <= 0;
                    timerActive <= 0;
                    powerUpVisible <= '0';
                end if;

            -- Hit Right
            elsif (BallX >= R_PaddleX - ballWidth) then -- X pos where ball can hit paddle of border
                if(ballY <= R_PaddleY + R_PaddleLength and ballY >= R_PaddleY - ballWidth) then -- Ball between top and bottom of paddle?
                    if (ballVelocityX > 0) then

                        if(BallY < R_PaddleY + R_PaddleLength/2) then -- Ball hits at top of paddle 
                            -- Increase X Speed each 10 pixels closer to middle of paddle
                            -- + Negative speed => ball moves left
                            ballVelocityX <= (ballY - R_paddleY)/(-10); 
                            -- Increase Y Speed each 10 pixels closer to top of paddle
                            -- + Negative speed => ball moves up 
                            ballVelocityY <= ((R_PaddleLength/2) - (ballY - R_paddleY))/(-10);

                        elsif (BallY = R_PaddleY + R_PaddleLength/2) then -- Ball hits at middle of paddle
                            ballVelocityX <= 6;

                        else -- Ball hits at bottom of paddle
                            -- Increase X Speed each 10 pixels closer to middle of paddle
                            -- + Negative speed => ball moves left
                            ballVelocityX <= ((R_paddleY + R_PaddleLength) - ballY)/(-10); 
                            -- Increase Y Speed each 10 pixels closer to top of paddle
                            -- + Positive speed => ball moves down
                            ballVelocityY <= (ballY - (R_paddleY + R_PaddleLength/2))/10;
                        end if;

                    end if ;
                else -- Goal => reset and L_score +1
                    ballX <= C_BallStartX;
                    BallY <= C_BallStartY;
                    ballVelocityX <= -3;
                    ballVelocityY <= -3;
                    L_Score <= L_Score + 1;
                    timerAppear <= 0;
                    timerActive <= 0;
                    powerUpVisible <= '0';
                end if;

            -- Hit Top
            elsif (BallY <= C_BorderWidth) then -- Ball hits top => positive Y speed
                if (ballVelocityY < 0) then
                    ballVelocityY <= - ballVelocityY;
                end if;

            -- Hit Bottom
            elsif (BallY >= G_VPixels - (C_BorderWidth + ballwidth)) then -- Ball hits bottom => negative Y speed
                if (ballVelocityY > 0) then
                    ballVelocityY <= - ballVelocityY;
                end if ;

            -- Hit Power
             -- Powerup visible and ball hits powerup
            elsif(ballX >= powerUpX and ballX <= powerUpX + powerUpWidth and ballY >= powerUpY and ballY <= powerUpY + powerUpWidth and powerUpVisible = '1') then
                powerUpActive <= '1'; -- powerup becomes active
                powerUpVisible <= '0'; -- powerup isn't visible 

                -- Go through different powerups 
                if powerUpCounter = 1 then -- Ball size
                    powerUpNr <= (0 => '1', others => '0'); 
                    powerUpCounter <= 2; -- Next Powerup

                elsif powerUpCounter = 2 then -- Paddle size +

                    if (ballVelocityX > 0) then -- Ball comes from left paddle
                        powerUpNr <= (1 => '1', others => '0'); -- Give left paddle + size

                    else -- Ball comes from right paddle
                        powerUpNr <= (2 => '1', others => '0'); -- Give right paddle + size
                    end if;

                    powerUpCounter <= 3;

                elsif powerUpCounter = 3 then -- Paddle size -

                    if (ballVelocityX < 0) then -- Ball comes from right paddle
                        powerUpNr <= (3 => '1', others => '0'); -- Give left paddle - size

                    else -- Ball comes from left paddle
                        powerUpNr <= (4 => '1', others => '0'); -- Give right paddle - size
                    end if;

                    powerUpCounter <= 1;
                end if;
            end if;
            
            -- Powerup Show
            if (timerAppear >= timeToAppear) then -- Make power up visible/unvisible for 15 sec
                timerAppear <= 0; 
                powerUpVisible <= not powerUpVisible;
            else
                timerAppear <= timerAppear + 1;
            end if;
            
            -- Powerup active
            if (powerUpActive = '1') then -- Time powerup stays active => 12 sec
                if (timerActive >= timeActive) then
                    timerActive <= 0;
                    powerUpActive <= '0';
                    powerUpVisible <= '0';
                    timerAppear <= 0;
                else
                    timerActive <= timerActive + 1;
                end if;
            end if;

        end if;
    end process;

    p_Segment: process(clk_200Hz) -- Display score on 2x2 7 segment displays 
    begin
        if rising_edge(clk_200Hz) then
            SEG_OFF <= (others => '1'); -- Middle 4 displays always off

            if (segment_counter = 0) then 
                AN <= "1110"; -- most right display 
                O <= cSegm(R_Score mod 10); -- ones of right score
                segment_counter <= segment_counter + 1; -- next display

            elsif (segment_counter = 1) then
                AN <= "1101"; -- second right display
                O <= cSegm(((R_Score - (R_Score mod 10)) mod 100)/10); -- tens of right score
                segment_counter <= segment_counter + 1;

            elsif (segment_counter = 2) then
                AN <= "1011"; -- second left display
                O <= cSegm(L_Score mod 10); -- ones of left score
                segment_counter <= segment_counter + 1;

            else
                AN <= "0111"; -- most left display
                O <= cSegm(((L_Score -(L_Score mod 10)) mod 100)/10); -- tens of left score
                segment_counter <= 0;

            end if;
        end if;
    end process;

    
    p_Display: process(Hpixelcount, Vpixelcount, L_PaddleX, L_PaddleY, L_PaddleLength, R_PaddleX, R_PaddleY, R_PaddleLength, ballX, ballY, ballWidth, powerUpX, powerUpY, powerUpWidth, powerUpVisible, powerUpCounter)
    begin -- Send pixels information of diffrent objects if pixel counts are between limits

        -- Border
        if ((HPixelCount <= C_BorderWidth and VPixelCount <= G_VPixels) or (HPixelCount <= G_HPixels and VPixelCount <= C_BorderWidth) or (HPixelCount >= G_HPixels - C_BorderWidth  and HPixelCount <= G_HPixels and VPixelCount <= G_VPixels) or (HPixelCount <= G_HPixels and VPixelCount >= G_Vpixels - C_BorderWidth  and VPixelCount <= G_Vpixels))then
            VGA_R <= (others => '1');
            VGA_G <= (others => '1');
            VGA_B <= (others => '1');
        -- PowerUp
            --Powerup size => yellow
        elsif(HPixelCount >= powerUpX and HPixelCount <= powerUpX + powerUpWidth and VPixelCount >= powerUpY and VPixelCount <= powerUpY + powerUpWidth and powerUpVisible = '1' and powerUpCounter = 2) then
            VGA_R <= (others => '1');
            VGA_G <= (others => '1');
            VGA_B <= (others => '0');  
            --PowerUp + paddle size => green
        elsif(HPixelCount >= powerUpX and HPixelCount <= powerUpX + powerUpWidth and VPixelCount >= powerUpY and VPixelCount <= powerUpY + powerUpWidth and powerUpVisible = '1' and powerUpCounter = 3) then
            VGA_R <= (others => '0');
            VGA_G <= (others => '1');
            VGA_B <= (others => '0');
            --Powerup - paddle size => red 
        elsif(HPixelCount >= powerUpX and HPixelCount <= powerUpX + powerUpWidth and VPixelCount >= powerUpY and VPixelCount <= powerUpY + powerUpWidth and powerUpVisible = '1' and powerUpCounter = 1) then
            VGA_R <= (others => '1');
            VGA_G <= (others => '0');
            VGA_B <= (others => '0'); 
        -- Ball
        elsif (HPixelCount >= ballX and HpixelCount <= ballX + ballWidth and VPixelCount >= ballY and Vpixelcount <= ballY + ballWidth) then
            VGA_R <= (others => '1');
            VGA_G <= (others => '0');
            VGA_B <= (others => '0');
        -- Centerline
        elsif (HPixelCount = G_Hpixels/2 and VPixelCount <= G_VPixels) then
            VGA_R <= (others => '1');
            VGA_G <= (others => '1');
            VGA_B <= (others => '1');
        -- Left paddle
        elsif(HPixelCount >= L_PaddleX and HPixelCount <= L_paddleX + C_paddleWidth and VPixelCount >= L_PaddleY and VPixelCount <= L_PaddleY + L_paddleLength) then
            VGA_R <= (others => '1');
            VGA_G <= (others => '0');
            VGA_B <= (others => '1');
        -- Right paddle
        elsif(HPixelCount >= R_PaddleX and HPixelCount <= R_paddleX + C_paddleWidth and VPixelCount >= R_PaddleY and VPixelCount <= R_PaddleY + R_paddleLength) then
            VGA_R <= (others => '0');
            VGA_G <= (others => '0');
            VGA_B <= (others => '1');
        else
            VGA_R <= (others => '0');
            VGA_G <= (others => '0');
            VGA_B <= (others => '0');
        end if;
    end process;

end Behavioral;