
% The Setup
% 
% Imagine you want to send a message wirelessly — say, from a moving car to a tower. The signal doesn't travel in a straight line; it bounces off buildings, hills, other cars — so the receiver gets several copies of the same signal, each arriving a little later than the first, and each one slightly "off pitch" because things are moving (just like how an ambulance siren changes pitch as it passes you).
% 
% We wanted to test two different ways of packaging data for this kind of journey — one called OFDM (the older, widely-used method) and one called OTFS (a newer method) — and see which one survives this messy, moving environment better.
% 
% Building the Data
% 
% First, we created a grid — think of it like a spreadsheet, 64 rows by 30 columns — and filled every cell with random data symbols, like filling a crossword puzzle with random letters. We made one such grid for OFDM and a separate one for OTFS, since each method organizes data differently under the hood, even though the grid size was the same.
% 
% Building a "Test Signal" to Learn the Environment
% 
% Before trusting the real data, we needed to learn what the wireless environment (the bouncing, the pitch-shifting) actually does to a signal. So we made two more grids — this time not carrying a message, just a known "test tone":
% 
% - For OTFS, we only needed one single test symbol, placed carefully in an otherwise empty grid.
% - For OFDM, we needed to fill the entire grid with test tones, one in every single cell.
% 
% This difference is the first hint of OTFS's advantage — it needs far less "overhead" to learn the environment.
% 
% Sending Everything Through the Same Storm
% 
% We then took all four grids — 2 real-data grids, 2 test-tone grids — and sent each one through the same simulated environment: 3 bouncing paths, each with its own delay and its own pitch-shift, plus background static (noise) added on top. Same storm, same rules, applied fairly to both methods.
% 
% Learning What the Storm Did
% 
% Using the test-tone grids (which we knew in advance), we compared what we sent versus what came out the other side. The difference told us exactly how the storm distorted things — how much delay, how much pitch shift, how much the signal got weaker along each path. This is like sending a known reference photo through a foggy camera, then comparing it to the original to figure out exactly how foggy it was.
% 
% Cleaning Up the Real Data
% 
% Now that we knew exactly what the storm did, we used that knowledge to "undo" the damage on the real data grids — like applying a filter to remove exactly the fog we measured. Each method (OTFS and OFDM) applied its own way of undoing the distortion, using its own test-tone-derived measurement.
% 
% Checking the Results
% 
% We compared the cleaned-up data against the original data we sent — counting how many bits came out wrong (error rate) and how far off each recovered data point landed from where it should have been (a kind of "aim accuracy" score).
% 
% The Big Discovery
% 
% We repeated this whole experiment at many different levels of background noise, from very noisy to almost silent. Here's what we found:
% 
% - OTFS got better and better as the noise went down, eventually recovering the message perfectly — zero errors.
% - OFDM also improved as noise went down — but only up to a point. Even in near-silence, it kept making the same small number of mistakes, over and over, no matter how quiet things got.
% 
% Why
% 
% The reason isn't noise — it's the "pitch-shifting" from movement. That pitch-shift causes each piece of data to bleed slightly into its neighbors, like ink smudging between adjacent letters. OFDM's cleanup method simply isn't designed to notice or undo that kind of smudging — it only knows how to fix one letter at a time, in isolation. OTFS's cleanup method, by contrast, is built to understand and undo that smudging directly, because it was designed with movement and pitch-shift in mind from the start.
% 
% The Takeaway
% 
% In a world with moving objects — cars, drones, trains — OTFS handles the resulting distortion in a way OFDM structurally cannot, no matter how good the connection otherwise is. That's the whole story this experiment was built to show, step by step, from scratch.

%% ================= Variable Controls =================
PLOT = true;

%% ================= Parameters =================
M = 64;        % delay bins
N = 30;        % Doppler bins
padLen = 10;   % zero-pad length
padType = 'ZP';
SNRdB = 40;

%% Step 1 & 2: Data Generation — OTFS & OFDM (merged plot)

bitsPerSym = 2;
dataBits = randi([0 1], bitsPerSym, M*N);                   % 2 x 1920 random bits
dataSymbols = pskmod(dataBits, 4, pi/4, InputType="bit");    % 1 x 1920 QPSK symbols
Xdd = reshape(dataSymbols, M, N);                             % 64 x 30 grid, fully populated

dataBits_ofdm = randi([0 1], bitsPerSym, M*N);                    % 2 x 1920 random bits
dataSymbols_ofdm = pskmod(dataBits_ofdm, 4, pi/4, InputType="bit"); % 1 x 1920 QPSK symbols
Xofdm = reshape(dataSymbols_ofdm, M, N);                            % 64 x 30 grid

if PLOT
    figure('Name','Step 1-2: Data Grids — OTFS & OFDM');

    subplot(1,2,1);
    imagesc(0:N-1, 0:M-1, abs(Xdd));
    title('Xdd: OTFS Data Grid');
    xlabel('Doppler index'); ylabel('Delay index'); colorbar;

    subplot(1,2,2);
    imagesc(0:N-1, 0:M-1, abs(Xofdm));
    title('Xofdm: OFDM Data Grid');
    xlabel('OFDM symbol index'); ylabel('Subcarrier index'); colorbar;
end

%% Step 3: Modulation

txOTFS = helperOTFSmod(Xdd, padLen, padType);
txOFDM = ofdmmod(Xofdm, M, padLen);

if PLOT
    figure('Name','Step 3: Modulated Time-Domain Signals');
    subplot(2,1,1);
    plot(abs(txOTFS));
    title('OTFS Tx Signal (Magnitude)');
    xlabel('Sample index'); ylabel('|amp|');

    subplot(2,1,2);
    plot(abs(txOFDM));
    title('OFDM Tx Signal (Magnitude)');
    xlabel('Sample index'); ylabel('|amp|');
end

%% Step 4: Channel

df = 15e3;                              % LTE subcarrier spacing (Hz)
fc = 5e9;                               % carrier frequency (Hz), for physical interpretation later
fsamp = M*df;                           % sampling frequency = 960 kHz
Meff = M + padLen;                      % samples per subsymbol/OFDM symbol incl. padding = 74
T = Meff/(M*df);                        % subsymbol duration (s)

chanParams.pathDelays   = [0  5   8  ];               % 3 paths' delays in samples
chanParams.pathGains    = [1  0.7 0.5];                % 3 paths' complex gains
chanParams.pathDopplers = [0 -3   5  ];                 % 3 paths' Doppler offsets (normalized index)
chanParams.pathDopplerFreqs = chanParams.pathDopplers * 1/(N*T);  % convert to actual Doppler in Hz

dopplerOutOTFS = dopplerChannel(txOTFS, fsamp, chanParams);   % apply multipath+Doppler to OTFS signal
chOutOTFS = awgn(dopplerOutOTFS, SNRdB, 'measured');            % add AWGN noise at 40dB SNR

dopplerOutOFDM = dopplerChannel(txOFDM, fsamp, chanParams);   % apply same channel to OFDM signal
chOutOFDM = awgn(dopplerOutOFDM, SNRdB, 'measured');            % add AWGN noise, same SNR

if PLOT
    figure('Name','Step 4: Received Signals After Channel');
    subplot(2,1,1);
    plot(abs(chOutOTFS));                       % magnitude of OTFS Rx signal
    title('OTFS Rx Signal (after channel + noise)');
    xlabel('Sample index'); ylabel('|amp|');

    subplot(2,1,2);
    plot(abs(chOutOFDM));                       % magnitude of OFDM Rx signal
    title('OFDM Rx Signal (after channel + noise)');
    xlabel('Sample index'); ylabel('|amp|');
end

%% Step 5: Demodulation

numSamps = Meff*N;                          % one frame length = 2220

rxOTFS = chOutOTFS(1:numSamps);             % trim extra 8 samples from channel delay extension
Ydd = helperOTFSdemod(rxOTFS, M, padLen, 0, padType);   % back to delay-Doppler domain

rxOFDM = chOutOFDM(1:numSamps);             % trim extra 8 samples
Yofdm = ofdmdemod(rxOFDM, M, padLen);        % back to subcarrier/symbol domain

if PLOT
    figure('Name','Step 5: Original vs Demodulated Grids');

    subplot(2,2,1);
    imagesc(0:N-1, 0:M-1, abs(Xdd));
    title('Original Grid (Xdd)');
    xlabel('Doppler index'); ylabel('Delay index'); colorbar;

    subplot(2,2,2);
    imagesc(0:N-1, 0:M-1, abs(Ydd));
    title('OTFS Demodulated (Ydd)');
    xlabel('Doppler index'); ylabel('Delay index'); colorbar;

    subplot(2,2,3);
    imagesc(0:N-1, 0:M-1, abs(Xofdm));
    title('Original Grid (Xofdm)');
    xlabel('Symbol index'); ylabel('Subcarrier index'); colorbar;

    subplot(2,2,4);
    imagesc(0:N-1, 0:M-1, abs(Yofdm));
    title('OFDM Demodulated (Yofdm)');
    xlabel('Symbol index'); ylabel('Subcarrier index'); colorbar;
end

%% Step 6: Dedicated Pilot Grids — OTFS (single pilot) & OFDM (full-grid pilot)
% OTFS: one pilot is enough (DD-domain sparsity reveals the whole channel).
% OFDM: needs a pilot on EVERY subcarrier/symbol, since each subcarrier's
% channel value is independent and one pilot can't reveal the rest.

pilotBin = floor(N/2)+1;      % 16 -> OTFS pilot placed at column 16
pilotVal = exp(1i*pi/4);       % known reference symbol (same value used by both)

Xpilot = zeros(M,N);             % OTFS pilot grid: empty except one cell
Xpilot(1, pilotBin) = pilotVal;

Xpilot_ofdm = pilotVal * ones(M,N);   % OFDM pilot grid: pilot in every cell

if PLOT
    figure('Name','Step 6: Pilot Grids — OTFS & OFDM');

    subplot(1,2,1);
    imagesc(0:N-1, 0:M-1, abs(Xpilot));
    title('OTFS Pilot Grid (Xpilot)');
    xlabel('Doppler index'); ylabel('Delay index'); colorbar;

    subplot(1,2,2);
    imagesc(0:N-1, 0:M-1, abs(Xpilot_ofdm));
    title('OFDM Pilot Grid (Xpilot_{ofdm})');
    xlabel('Symbol index'); ylabel('Subcarrier index'); colorbar;
end

%% Step 7 & 7b: Channel Estimation — OTFS & OFDM (merged plot)

% --- OTFS: estimate from pilot-only frame ---
txPilot = helperOTFSmod(Xpilot, padLen, padType);
dopplerOutPilot = dopplerChannel(txPilot, fsamp, chanParams);
chOutPilot = awgn(dopplerOutPilot, SNRdB, 'measured');
rxPilot = chOutPilot(1:numSamps);
Ydd_pilot = helperOTFSdemod(rxPilot, M, padLen, 0, padType);

Es = mean(abs(pskmod(0:3,4,pi/4).^2));      % average QPSK symbol energy
n0 = Es/(10^(SNRdB/10));                      % noise power from SNR

Hdd = Ydd_pilot * conj(pilotVal) / (abs(pilotVal)^2 + n0);   % LMMSE channel estimate

[lp,vp] = find(abs(Hdd) >= 0.05);            % threshold to find path peaks
chanEst.pathGains    = diag(Hdd(lp,vp));      % complex gain of each detected path
chanEst.pathDelays   = lp - 1;                  % delay index (0-indexed)
chanEst.pathDopplers = vp - pilotBin;            % Doppler offset relative to pilot

% Check:
% chanEst.pathDelays     % should be ~[0 5 8]
% chanEst.pathDopplers    % should be ~[0 -3 5]
% abs(chanEst.pathGains)  % should be ~[1 0.7 0.5]

% --- OFDM: estimate from full-grid pilot frame ---
txPilotOFDM = ofdmmod(Xpilot_ofdm, M, padLen);
dopplerPilotOFDM = dopplerChannel(txPilotOFDM, fsamp, chanParams);
chPilotOFDM = awgn(dopplerPilotOFDM, SNRdB, 'measured');
YofdmPilot = ofdmdemod(chPilotOFDM(1:numSamps), M, padLen);

Hofdm = YofdmPilot * conj(pilotVal) / (abs(pilotVal)^2 + n0);   % LMMSE channel estimate

if PLOT
    figure('Name','Step 7: Channel Response — OTFS & OFDM');

    subplot(1,2,1);
    mesh(0:N-1, 0:M-1, abs(Hdd));
    view([-9.441 62.412]);
    title('Hdd: OTFS Channel Response');
    xlabel('Normalized Doppler'); ylabel('Normalized Delay'); zlabel('Magnitude');

    subplot(1,2,2);
    mesh(0:N-1, 0:M-1, abs(Hofdm));
    title('Hofdm: OFDM Channel Response');
    xlabel('OFDM Symbol index'); ylabel('Subcarrier index'); zlabel('Magnitude');
end

%% Step 8: Physical Interpretation of Estimated OTFS Channel

c = physconst('LightSpeed');   % speed of light, m/s

fprintf('\n--- Estimated Channel Paths (Physical Units) ---\n');
for p = 1:length(chanEst.pathDelays)
    delay_s = chanEst.pathDelays(p) / fsamp;             % delay in seconds
    delay_us = delay_s * 1e6;                             % delay in microseconds

    dopplerFreq = chanEst.pathDopplers(p) * 1/(N*T);       % Doppler in Hz
    speed_mps = dopplerFreq * c / fc;                       % Doppler -> relative speed (m/s)
    speed_kmh = speed_mps * 3.6;                             % m/s -> km/h

    fprintf('Scatterer %d\n', p);
    fprintf('\tDelay = %5.2f us\n', delay_us);
    fprintf('\tRelative Doppler shift = %5.0f Hz (%5.0f km/h)\n\n', dopplerFreq, speed_kmh);
end

%% Step 9: Equalization

% --- OTFS: time-domain LMMSE using estimated channel matrix G ---
G = getG(M,N,chanEst,padLen,padType);
y_otfs = ((G'*G)+n0*eye(Meff*N)) \ (G'*rxOTFS);
Xhat_otfs = helperOTFSdemod(y_otfs,M,padLen,0,padType);

% --- OFDM: single-tap FDE using Hofdm ---
Xhat_ofdm = conj(Hofdm) .* Yofdm ./ (abs(Hofdm).^2+n0);

if PLOT
    figure('Name','Step 9: Recovered Constellations');

    subplot(1,2,1);
    plot(real(Xhat_otfs(:)), imag(Xhat_otfs(:)), '.');
    title('OTFS Recovered Constellation');
    xlabel('I'); ylabel('Q'); axis equal; grid on;

    subplot(1,2,2);
    plot(real(Xhat_ofdm(:)), imag(Xhat_ofdm(:)), '.');
    title('OFDM Recovered Constellation');
    xlabel('I'); ylabel('Q'); axis equal; grid on;
end

%% Step 10: BER Comparison

bitsOTFS = pskdemod(Xhat_otfs, 4, pi/4, OutputType="bit", OutputDataType="double");
bitsOFDM = pskdemod(Xhat_ofdm, 4, pi/4, OutputType="bit", OutputDataType="double");

berOTFS = mean(bitsOTFS(:) ~= dataBits(:));
berOFDM = mean(bitsOFDM(:) ~= dataBits_ofdm(:));

fprintf('\n--- BER Results (SNR = %d dB) ---\n', SNRdB);
fprintf('OTFS BER = %.4f\n', berOTFS);
fprintf('OFDM BER = %.4f\n', berOFDM);

if PLOT
    figure('Name','Step 10: BER Comparison');
    bar(categorical({'OTFS','OFDM'}), [berOTFS berOFDM]);
    title('Bit Error Rate Comparison');
    ylabel('BER');
end

%% Step 11: SNR Sweep — BER + EVM Table

SNRrange = 0:10:100;
numSNR = length(SNRrange);

berOTFS_sweep = zeros(numSNR,1);
berOFDM_sweep = zeros(numSNR,1);
evmOTFS_sweep = zeros(numSNR,1);
evmOFDM_sweep = zeros(numSNR,1);

for idx = 1:numSNR
    SNRdB = SNRrange(idx);

    Es = mean(abs(pskmod(0:3,4,pi/4).^2));
    n0 = Es/(10^(SNRdB/10));

    % --- Channel + noise: data frames ---
    dopplerOutOTFS = dopplerChannel(txOTFS, fsamp, chanParams);
    chOutOTFS = awgn(dopplerOutOTFS, SNRdB, 'measured');

    dopplerOutOFDM = dopplerChannel(txOFDM, fsamp, chanParams);
    chOutOFDM = awgn(dopplerOutOFDM, SNRdB, 'measured');

    % --- Demodulation: data frames ---
    rxOTFS = chOutOTFS(1:numSamps);
    Ydd = helperOTFSdemod(rxOTFS, M, padLen, 0, padType);

    rxOFDM = chOutOFDM(1:numSamps);
    Yofdm = ofdmdemod(rxOFDM, M, padLen);

    % --- Channel estimation: OTFS (pilot-only frame) ---
    txPilot = helperOTFSmod(Xpilot, padLen, padType);
    dopplerOutPilot = dopplerChannel(txPilot, fsamp, chanParams);
    chOutPilot = awgn(dopplerOutPilot, SNRdB, 'measured');
    rxPilot = chOutPilot(1:numSamps);
    Ydd_pilot = helperOTFSdemod(rxPilot, M, padLen, 0, padType);

    Hdd = Ydd_pilot * conj(pilotVal) / (abs(pilotVal)^2 + n0);
    [sortedVals, sortedIdx] = sort(abs(Hdd(:)), 'descend');
    topIdx = sortedIdx(1:3);
    [lp, vp] = ind2sub([M,N], topIdx);
    chanEst.pathGains    = Hdd(topIdx);
    chanEst.pathDelays   = lp - 1;
    chanEst.pathDopplers = vp - pilotBin;

    % --- Channel estimation: OFDM (full-grid pilot frame) ---
    txPilotOFDM = ofdmmod(Xpilot_ofdm, M, padLen);
    dopplerPilotOFDM = dopplerChannel(txPilotOFDM, fsamp, chanParams);
    chPilotOFDM = awgn(dopplerPilotOFDM, SNRdB, 'measured');
    YofdmPilot = ofdmdemod(chPilotOFDM(1:numSamps), M, padLen);
    Hofdm = YofdmPilot * conj(pilotVal) / (abs(pilotVal)^2 + n0);

    % --- Equalization ---
    G = getG(M,N,chanEst,padLen,padType);
    y_otfs = ((G'*G)+n0*eye(Meff*N)) \ (G'*rxOTFS);
    Xhat_otfs = helperOTFSdemod(y_otfs,M,padLen,0,padType);

    Xhat_ofdm = conj(Hofdm) .* Yofdm ./ (abs(Hofdm).^2+n0);

    % --- BER ---
    bitsOTFS = pskdemod(Xhat_otfs, 4, pi/4, OutputType="bit", OutputDataType="double");
    bitsOFDM = pskdemod(Xhat_ofdm, 4, pi/4, OutputType="bit", OutputDataType="double");
    berOTFS_sweep(idx) = mean(bitsOTFS(:) ~= dataBits(:));
    berOFDM_sweep(idx) = mean(bitsOFDM(:) ~= dataBits_ofdm(:));

    % --- EVM ---
    evmOTFS_sweep(idx) = sqrt(mean(abs(Xhat_otfs(:) - Xdd(:)).^2)) / sqrt(mean(abs(Xdd(:)).^2)) * 100;
    evmOFDM_sweep(idx) = sqrt(mean(abs(Xhat_ofdm(:) - Xofdm(:)).^2)) / sqrt(mean(abs(Xofdm(:)).^2)) * 100;
end

resultsTable = table(SNRrange', berOTFS_sweep, berOFDM_sweep, evmOTFS_sweep, evmOFDM_sweep, ...
    'VariableNames', {'SNR_dB','BER_OTFS','BER_OFDM','EVM_OTFS_pct','EVM_OFDM_pct'});

disp(resultsTable);


