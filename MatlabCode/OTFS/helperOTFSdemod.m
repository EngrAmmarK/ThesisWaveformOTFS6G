function [y,tfout] = helperOTFSdemod(x,M,padlen,offset,varargin)
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

if strcmp(padtype,'CP') || strcmp(padtype,'ZP')
    N = size(x,1)/(M+padlen);
    assert((N - round(N)) < sqrt(eps));
    rx = reshape(x,M+padlen,N);
    Y = rx(1+offset:M+offset,:);
elseif strcmp(padtype,'NONE')
    N = size(x,1)/M;
    assert((N - round(N)) < sqrt(eps));
    Y = reshape(x,M,N);
elseif strcmp(padtype,'RCP') || strcmp(padtype,'RZP')
    N = (size(x,1)-padlen)/M;
    assert((N - round(N)) < sqrt(eps));
    rx = x(1+offset:M*N+offset);
    Y = reshape(rx,M,N);
else
    error('Invalid pad type');
end

tfout = fft(Y);
y = fft(Y.').' * M;

if plotFlag
    rowsToPlot = [1 2];
    figure;
    for k = 1:length(rowsToPlot)
        r = rowsToPlot(k);
        subplot(length(rowsToPlot),2,2*k-1);
        plot(real(Y(r,:))); hold on; plot(imag(Y(r,:)));
        title(sprintf('Before FZT (delay-time) - Row %d',r)); xlabel('Time index');

        subplot(length(rowsToPlot),2,2*k);
        stem(real(y(r,:))); hold on; stem(imag(y(r,:)));
        title(sprintf('After FZT (delay-Doppler) - Row %d',r)); xlabel('Doppler index');
    end
end
end