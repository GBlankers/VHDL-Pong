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
        CLK100MHZ: in std_logic;                    -- System clock
        RES: in std_logic;                          -- Asynchronous reset
        R_MOVE: in std_logic;                       -- Right paddle movement
        L_MOVE: in std_logic;                       -- Left paddle movement
        R_CPU: in std_logic;                        -- Enable cpu right paddle
        L_CPU: in std_logic;                        -- Enable cpu left paddle
        AN: out std_logic_vector (3 downto 0);      -- Anode active 7 segment displays
        O: out std_logic_vector (6 downto 0);       -- Output 7 segment displays
        SEG_OFF: out std_logic_vector (3 downto 0); -- Anode not active 7 segment displays
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
    
    signal pixel_clk : std_logic;
    signal clk_200Hz : std_logic := '0';
    signal clk_5MHz  : std_logic;
    signal clk_60hz  : std_logic;

    signal clk_count: integer := 12500; -- 5MHz => 200Hz
    signal counter: integer := 0;

    signal segment_counter: integer;
    
    signal HPixelCount : integer := 0;
    signal VPixelCount : integer := 0;

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
    signal timeToAppear : integer := 900; 
    signal timer1 : integer := 0;
    signal timeActive : integer := 720;
    signal timer2 : integer := 0;
    signal powerUpVisible : std_logic := '0';
    signal powerUpActive : std_logic := '0';
    signal powerUpX : integer := 610;
    signal powerUpY : integer := 482;
    signal powerUpWidth : integer := 60;
    signal powerUpNr : integer := 0;
    signal powerUps : integer := 3;
    
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
        clk_out => pixel_clk,
        clk_out2 => clk_5MHz,
        reset => RES
    );

    p_clkPrescale: process(clk_5MHz)
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

    p_HSync: process(HPixelCount)
    begin
        if ((HPixelCount >= G_Hfp + G_Hpixels) and (HPixelCount <= G_Hfp + G_Hpulse + G_Hpixels)) then
            VGA_HS <= G_Active;
        else
            VGA_HS <= not G_Active;
        end if;
    end process;
  
    p_VSync: process(VPixelCount)
    begin
        if ((VPixelCount >= G_Vfp + G_Vpixels) and (VPixelCount <= G_Vfp + G_Vpulse + G_Vpixels)) then
            VGA_VS <= G_Active;
        else
            VGA_VS <= not G_Active;
        end if;
    end process;

    p_Pixels: process(pixel_clk, RES)
    begin
        if (RES = '1') then
            HPixelCount <= 0;
            VPixelCount <= 0;
        elsif(rising_edge(pixel_clk)) then
            if(HPixelCount = C_HPeriod) then 
                HPixelCount <= 0;
                if (VPixelCount = C_VPeriod) then
                    VPixelCount <= 0;
                    clk_60hz <= G_active;
                else
                    VPixelCount <= VPixelCount + 1;
                    clk_60hz <= not G_active;
                end if;
            else
                HPixelCount <= HPixelCount + 1;
            end if;
        end if;
    end process;

    -- Right paddle movement
    p_RPaddle: process(clk_60hz)
    begin
        if rising_edge(clk_60hz) then
            if (R_CPU = '1') then
                R_paddleSpeed <= C_CPUPaddleSpeed;
                if (ballY <= R_PaddleY + R_PaddleLength /2 and ballX >= G_HPixels/2 and R_PaddleY >= C_BorderWidth) then
                    R_PaddleY <= R_PaddleY - R_paddleSpeed;
                elsif (ballY >= R_PaddleY + R_PaddleLength /2 and ballX >= G_HPixels/2 and R_PaddleY <= G_VPixels - (C_BorderWidth + R_PaddleLength)) then
                    R_PaddleY <= R_PaddleY + R_paddleSpeed;
                elsif (R_PaddleY <= G_Vpixels/2 - R_PaddleLength/2 and ballX <= G_HPixels/2) then
                    R_PaddleY <= R_PaddleY + (R_paddleSpeed - 2);
                elsif (R_PaddleY >= G_Vpixels/2 - R_PaddleLength/2 and ballX <= G_HPixels/2) then
                    R_PaddleY <= R_PaddleY - (R_paddleSpeed - 2);
                end if ;
            else
                R_paddleSpeed <= C_playerPaddleSpeed;
                if (R_Move = '0' and R_PaddleY <= G_VPixels - (C_BorderWidth + R_PaddleLength)) then
                    R_PaddleY <= R_PaddleY + R_paddleSpeed;
                elsif (R_Move = '1' and R_PaddleY >= C_BorderWidth) then
                    R_PaddleY <= R_PaddleY - R_paddleSpeed;
                end if;
            end if ;
        end if;
    end process;

    -- Left paddle movement
    p_LPaddle: process(clk_60hz)
    begin
        if rising_edge(clk_60hz) then
            if (L_CPU = '1') then
                L_paddleSpeed <= C_CPUPaddleSpeed;
                if (ballY <= L_PaddleY + L_PaddleLength /2 and ballX <= G_HPixels/2 and L_PaddleY >= C_BorderWidth) then
                    L_PaddleY <= L_PaddleY - L_paddleSpeed;
                elsif (ballY >= L_PaddleY + L_PaddleLength /2 and ballX <= G_HPixels/2 and L_PaddleY <= G_VPixels - (C_BorderWidth + L_PaddleLength)) then
                    L_PaddleY <= L_PaddleY + L_paddleSpeed;
                elsif (L_PaddleY <= G_Vpixels/2 - L_PaddleLength/2 and ballX >= G_HPixels/2) then
                    L_PaddleY <= L_PaddleY + (L_paddleSpeed - 2);
                elsif (L_PaddleY >= G_Vpixels/2 - L_PaddleLength/2 and ballX >= G_HPixels/2) then
                    L_PaddleY <= L_PaddleY - (L_paddleSpeed - 2);  
                end if ;
            else
                L_paddleSpeed <= C_playerPaddleSpeed;
                if (L_Move = '0' and L_PaddleY <= G_VPixels - (C_BorderWidth + L_PaddleLength)) then
                    L_PaddleY <= L_PaddleY + L_paddleSpeed;
                elsif (L_Move = '1' and L_PaddleY >= C_BorderWidth) then
                    L_PaddleY <= L_PaddleY - L_paddleSpeed;
                end if;
            end if ;
        end if;
    end process;

    p_Ball: process(clk_60hz, RES)
    begin
        if(RES = '1') then
            ballX <= C_BallStartX;
            ballY <= C_BallStartY;
            L_Score <= 0;
            R_Score <= 0;
            timer1 <= 0;
            timer2 <= 0;
            powerUpVisible <= '0';
        elsif rising_edge(clk_60hz) then

            -- Ball Movement
            ballX <= ballX + ballVelocityX;
            ballY <= ballY + ballVelocityY;

            -- Powerup
            if (powerUpActive = '1') then
                if (ballwidth = C_BallstartWidth) then
                    ballwidth <= ballwidth * 2;
                end if;
            else
                ballwidth <= C_BallStartWidth;
            end if;
            
            -- Ball Hits

            -- Hit Left
            if (BallX <= L_PaddleX + C_Paddlewidth) then
                if(ballY <= L_PaddleY + L_PaddleLength and ballY >= L_PaddleY - ballwidth) then
                    if (ballVelocityX < 0) then
                        if(BallY < L_PaddleY + L_PaddleLength/2) then
                            ballVelocityX <= (ballY - L_paddleY)/10; 
                            ballVelocityY <= ((L_PaddleLength/2) - (ballY - L_paddleY))/(-10);
                        elsif (BallY = L_PaddleY + L_PaddleLength/2) then
                            ballVelocityX <= 6;
                        else
                            ballVelocityX <= ((L_paddleY + L_PaddleLength) - ballY)/10; 
                            ballVelocityY <= (ballY - (L_paddleY + L_PaddleLength/2))/10;
                        end if;
                    end if ;
                else
                    ballX <= C_BallStartX;
                    BallY <= C_BallStartY;
                    ballVelocityX <= 3;
                    ballVelocityY <= 3;
                    R_Score <= R_Score + 1;
                    timer1 <= 0;
                    timer2 <= 0;
                    powerUpVisible <= '0';
                end if;

            -- Hit Right
            elsif (BallX >= R_PaddleX - ballWidth) then
                if(ballY <= R_PaddleY + R_PaddleLength and ballY >= R_PaddleY - ballWidth) then
                    if (ballVelocityX > 0) then
                        if(BallY < R_PaddleY + R_PaddleLength/2) then
                            ballVelocityX <= (ballY - R_paddleY)/(-10); 
                            ballVelocityY <= ((R_PaddleLength/2) - (ballY - R_paddleY))/(-10);
                        elsif (BallY = R_PaddleY + R_PaddleLength/2) then
                            ballVelocityX <= 4;
                        else
                            ballVelocityX <= ((R_paddleY + R_PaddleLength) - ballY)/(-10); 
                            ballVelocityY <= (ballY - (R_paddleY + R_PaddleLength/2))/10;
                        end if;
                    end if ;
                else
                    ballX <= C_BallStartX;
                    BallY <= C_BallStartY;
                    ballVelocityX <= -3;
                    ballVelocityY <= -3;
                    L_Score <= L_Score + 1;
                    timer1 <= 0;
                    timer2 <= 0;
                    powerUpVisible <= '0';
                end if;

            -- Hit Top
            elsif (BallY <= C_BorderWidth) then
                if (ballVelocityY < 0) then
                    ballVelocityY <= - ballVelocityY;
                end if;

            -- Hit Bottom
            elsif (BallY >= G_VPixels - (C_BorderWidth + ballwidth)) then
                if (ballVelocityY > 0) then
                    ballVelocityY <= - ballVelocityY;
                end if ;

            -- Hit Power
            elsif(ballX >= powerUpX and ballX <= powerUpX + powerUpWidth and ballY >= powerUpY and ballY <= powerUpY + powerUpWidth and powerUpVisible = '1') then
                powerUpActive <= '1';
                powerUpVisible <= '0';
            end if;
            
            -- Powerup Show
            if (timer1 >= timeToAppear) then
                timer1 <= 0;
                powerUpVisible <= not powerUpVisible;
            else
                timer1 <= timer1 + 1;
            end if;
            
            -- Powerup active
            if (powerUpActive = '1') then
                if (timer2 >= timeActive) then
                    timer2 <= 0;
                    powerUpActive <= '0';
                    powerUpVisible <= '0';
                else
                    timer2 <= timer2 + 1;
                end if;
            end if;

        end if;
    end process;

    p_Segment: process(clk_200Hz)
    begin
        if rising_edge(clk_200Hz) then
            SEG_OFF <= "1111";
            if (segment_counter = 0) then 
                AN <= "1110";
                O <= cSegm(R_Score mod 10);
                segment_counter <= segment_counter + 1;
            elsif (segment_counter = 1) then
                AN <= "1101";
                O <= cSegm(((R_Score - (R_Score mod 10)) mod 100)/10);
                segment_counter <= segment_counter + 1;
            elsif (segment_counter = 2) then
                AN <= "1011";
                O <= cSegm(L_Score mod 10);
                segment_counter <= segment_counter + 1;
            else
                AN <= "0111";
                O <= cSegm(((L_Score -(L_Score mod 10)) mod 100)/10) ;
                segment_counter <= 0;
            end if;
        end if;
    end process;

    
    p_Display: process(Hpixelcount, Vpixelcount, L_PaddleX, L_PaddleY, L_PaddleLength, R_PaddleX, R_PaddleY, R_PaddleLength, ballX, ballY, ballWidth, powerUpX, powerUpY, powerUpWidth, powerUpVisible)
    begin
        -- Border
        if ((HPixelCount <= C_BorderWidth and VPixelCount <= G_VPixels) or (HPixelCount <= G_HPixels and VPixelCount <= C_BorderWidth) or (HPixelCount >= G_HPixels - C_BorderWidth  and HPixelCount <= G_HPixels and VPixelCount <= G_VPixels) or (HPixelCount <= G_HPixels and VPixelCount >= G_Vpixels - C_BorderWidth  and VPixelCount <= G_Vpixels))then
            VGA_R <= (others => '1');
            VGA_G <= (others => '1');
            VGA_B <= (others => '1');
        -- PowerUp
        elsif(HPixelCount >= powerUpX and HPixelCount <= powerUpX + powerUpWidth and VPixelCount >= powerUpY and VPixelCount <= powerUpY + powerUpWidth and powerUpVisible = '1') then
            VGA_R <= (others => '1');
            VGA_G <= (others => '1');
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