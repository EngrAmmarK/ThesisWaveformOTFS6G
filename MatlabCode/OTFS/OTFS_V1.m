% Steps we're breaking this example into:
% 
% Build empty DD grid (M×N) ✅ current step
% Populate grid — place a single pilot symbol at one bin (channel sounding)
% OTFS modulation — inverse Zak transform (helperOTFSmod) → DD grid → time-domain signal, with zero-padding
% Channel — pass through high-mobility channel (LOS + scatterers with delay/Doppler/gain) + AWGN
% OTFS demodulation — forward Zak transform (helperOTFSdemod) → time-domain rx → back to DD grid Ydd
% Observe channel response — visualize how the pilot spread across Ydd (mesh plot), confirms delay/Doppler shift of each scatterer
% Channel estimation — LMMSE estimate Hdd from pilot, extract path gains/delays/Dopplers above a threshold
% Full data transmission — replace pilot with QPSK data grid, repeat modulation → channel → demodulation
% Equalization — OTFS: time-domain LMMSE using estimated channel matrix G; OFDM: single-tap FDE (for comparison)
% Compare BER — OTFS vs OFDM under same high-Doppler channel

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%&& STEP 1 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
M = 64;   % delay bins
N = 30 ;  % Doppler bins
Xdd = zeros(M, N);  % empty DD grid;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%&& STEP 2 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pilotBin = floor(N/2) + 1;      % pick a Doppler bin near the middle
Xdd(1, pilotBin) = exp(1i*pi/4); % place pilot at delay index 1, this Doppler bin

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%&& STEP 3 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
padLen = 10;      % zero-pad length, must exceed channel delay spread
padType = 'ZP';   % zero padding for ISI mitigation
[txOut, isfftOut] = helperOTFSmod(Xdd, padLen, padType, false);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%&& STEP 4 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

df = 15e3;
% Channel parameters
chanParams.pathDelays   = [0  5  8];   % samples
chanParams.pathGains    = [1  0.7 0.5];   % complex gain
chanParams.pathDopplers = [0 -3   5  ];   % normalized Doppler (multiple of 1/(N*T))

assert(strcmp(padType,'ZP'), 'Example must use ZP pad type');

fsamp = M*df;              % sampling frequency
Meff  = M + padLen;        % samples per subsymbol
numSamps = Meff * N;       % total samples per OTFS frame
T = (Meff/(M*df));         % subsymbol duration (s)

% Convert normalized Doppler indices to actual Doppler frequencies (Hz)
chanParams.pathDopplerFreqs = chanParams.pathDopplers * 1/(N*T);

% Pass through channel
dopplerOut = dopplerChannel(txOut, fsamp, chanParams);

% Add AWGN
SNRdB = 40;
Es = mean(abs(pskmod(0:3,4,pi/4).^2));
n0 = Es/(10^(SNRdB/10));
chOut = awgn(dopplerOut, SNRdB, 'measured');

if(false)
    t1 = 0:length(txOut)-1;
    t2 = 0:length(chOut)-1;
    
    figure;
    subplot(2,1,1);
    plot(t1, abs(txOut));
    title('Tx signal (before channel)');
    xlabel('Sample index'); ylabel('|amplitude|');
    
    subplot(2,1,2);
    plot(t2, abs(chOut));
    title('Rx signal (after channel + noise)');
    xlabel('Sample index'); ylabel('|amplitude|');
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% STEP 5 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

rxIn = chOut(1:numSamps);
% OTFS demodulation
Ydd = helperOTFSdemod(rxIn, M, padLen, 0, padType, false);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% STEP 6 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% When the pilot signal passes through the channel, each path shifts a copy of the pilot by its own (delay, Doppler) offset:
% Path 0 (direct/LOS): delay 0, Doppler 0 → pilot appears at (0+0, 15+0) = (0, 15) — unshifted, this is the "yellow" tall spike at Doppler=15
% Path 1 (scatterer 1): delay 5, Doppler -3 → pilot copy appears at (0+5, 15-3) = (5, 12) — one of the blue spikes at Doppler=12
% Path 2 (scatterer 2): delay 8, Doppler +5 → pilot copy appears at (0+8, 15+5) = (8, 20) — the other blue spike at Doppler=20

% LMMSE channel estimate in the delay-Doppler domain
Hdd = Ydd * conj(Xdd(1,pilotBin)) / (abs(Xdd(1,pilotBin))^2 + n0);

% Visualize
figure;
xa = 0:1:N-1;
ya = 0:1:M-1;
mesh(xa, ya, abs(Hdd));
view([-9.441 62.412]);
title('Delay-Doppler Channel Response H_{dd} from Channel Sounding');
xlabel('Normalized Doppler');
ylabel('Normalized Delay');
zlabel('Magnitude');


[lp, vp] = find(abs(Hdd) >= 0.05);
chanEst.pathGains    = diag(Hdd(lp,vp));   % complex gain of each detected path
chanEst.pathDelays   = lp - 1;             % delay indices (0-indexed)
chanEst.pathDopplers = vp - pilotBin;      % Doppler indices relative to pilotBin


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%% STEP 7 %%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[lp, vp] = find(abs(Hdd) >= 0.05);
chanEst.pathGains    = diag(Hdd(lp,vp));   % complex gain of each detected path
chanEst.pathDelays   = lp - 1;             % delay indices (0-indexed)
chanEst.pathDopplers = vp - pilotBin;      % Doppler indices relative to pilotBin

disp(chanEst.pathDelays)     % should be close to [0 5 8]
disp(chanEst.pathDopplers)   % should be close to [0 -3 5]
disp(abs(chanEst.pathGains)) % should be close to [1 0.7 0.5]clc

% Phase 1 (done): Channel sounding with a single pilot
% Built empty DD grid, placed 1 known pilot symbol
% OTFS modulated it (inverse Zak transform + zero padding)
% Passed through a 3-path high-mobility channel (delay + Doppler + gain) + noise
% OTFS demodulated back to DD domain (Ydd)
% Estimated the channel response Hdd via LMMSE using the known pilot
% Extracted the 3 paths' delay/Doppler/gain — confirmed they matched ground truth almost exactly
% Big takeaway: one pilot alone reveals the entire sparse multipath channel structure in the DD domain