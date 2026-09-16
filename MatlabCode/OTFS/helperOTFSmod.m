function [y,isfftout] = helperOTFSmod(x,padlen,varargin)
M = size(x,1);
if isempty(varargin)
    padtype = 'CP';
    plotFlag = false;
elseif length(varargin) == 1
    padtype = varargin{1};
    plotFlag = false;
else
    padtype = varargin{1};
    plotFlag = varargin{2};
end

% Inverse Zak transform
y = ifft(x.').' / M;

% Plot before/after IZT for a couple of rows
if plotFlag
    rowsToPlot = [1 2];
    figure;
    for k = 1:length(rowsToPlot)
        r = rowsToPlot(k);
        subplot(length(rowsToPlot),2,2*k-1);
        stem(real(x(r,:))); hold on; stem(imag(x(r,:)));
        title(sprintf('Before IZT - Row %d',r)); xlabel('Doppler index');

        subplot(length(rowsToPlot),2,2*k);
        plot(real(y(r,:))); hold on; plot(imag(y(r,:)));
        title(sprintf('After IZT - Row %d',r)); xlabel('Time index');
    end
end

% ISFFT to produce the TF grid output
isfftout = fft(y);

% Add cyclic prefix/zero padding according to padtype
switch padtype
case 'CP'
        y = [y(end-padlen+1:end,:); y];
        y = y(:);
case 'ZP'
        N = size(x,2);
        y = [y; zeros(padlen,N)];
        y = y(:);
case 'RZP'
        y = y(:);
        y = [y; zeros(padlen,1)];
case 'RCP'
        y = y(:);
        y = [y(end-padlen+1:end); y];
case 'NONE'
        y = y(:);
otherwise
        error('Invalid pad type');
end
end