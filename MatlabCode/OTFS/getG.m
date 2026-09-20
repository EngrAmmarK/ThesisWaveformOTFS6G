function G = getG(M,N,chanParams,padLen,padType)
    if strcmp(padType,'ZP') || strcmp(padType,'CP')
        Meff = M + padLen;
        lmax = padLen;
    else
        Meff = M;
        lmax = max(chanParams.pathDelays);
    end
    MN = Meff*N;
    P = length(chanParams.pathDelays);

    g = zeros(lmax+1,MN);
    for p = 1:P
        gp = chanParams.pathGains(p);
        lp = chanParams.pathDelays(p);
        vp = chanParams.pathDopplers(p);
        g(lp+1,:) = g(lp+1,:) + gp*exp(1i*2*pi/MN * vp*((0:MN-1)-lp));
    end

    G = zeros(MN,MN);
    for l = unique(chanParams.pathDelays).'
        G = G + diag(g(l+1,l+1:end),-l);
    end
end