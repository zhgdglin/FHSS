function result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, doPlots, opts)
%FHSS_4FSK_SIMULATE  统一版 FHSS+4FSK 仿真入口
%   result = fhss_4fsk_simulate(g, fs, snrDb, delay, seed, doPlots, opts)
%
% 统一后的可调参数：
% - 基础信道：snrDb(白噪声), delay(时延多径), opts.dopplerHz(多普勒频移)
% - 接收增强：opts.enableDopplerComp, opts.enableLMS, opts.enableViterbi
%
% 备注：
% - 为兼容历史调用，前 6 个位置参数保持不变。
% - 新增行为统一通过 opts 结构体控制。

if nargin < 5 || isempty(seed)
    seed = 1001203;
end
if nargin < 6 || isempty(doPlots)
    doPlots = true;
end
if nargin < 7 || isempty(opts)
    opts = struct();
end

% 默认可调参数
opts = apply_default_opts(opts);

symbolSamples = max(1, round(opts.symbolDurationMs * fs / 1000));
guardSamples = max(0, round(opts.guardIntervalMs * fs / 1000));
frameSamples = symbolSamples + guardSamples;
freqs = opts.freqs;

rng(seed, 'twister');

%% 1) 比特生成（可选卷积编码）
txBits = round(rand(1, g));
if opts.enableViterbi
    encoder = comm.ConvolutionalEncoder('TrellisStructure', poly2trellis(3, [7, 5]));
    codedBits = step(encoder, txBits(:)).';
else
    codedBits = txBits;
end

txBitsPadded = codedBits;
if mod(numel(txBitsPadded), 2) == 1
    txBitsPadded = [txBitsPadded 0];
end
numCodedBits = numel(codedBits);

%% 2) 原始比特波形（仅用于绘图）
signal1 = zeros(1, g * symbolSamples);
for k = 1:g
    if txBits(k) == 0
        signal1((k-1)*symbolSamples + (1:symbolSamples)) = -ones(1, symbolSamples);
    else
        signal1((k-1)*symbolSamples + (1:symbolSamples)) = ones(1, symbolSamples);
    end
end

%% 3) 4FSK 映射
ns = numel(txBitsPadded) / 2;
symbolMap = zeros(1, ns);
tSymbol = (0:symbolSamples-1) / fs;
signalFSK = zeros(1, ns * frameSamples);
for ksym = 1:ns
    b1 = txBitsPadded(2*ksym-1);
    b2 = txBitsPadded(2*ksym);
    idx = b1 * 2 + b2;
    symbolMap(ksym) = idx + 1;
    activeIdx1 = (ksym-1)*frameSamples + 1;
    activeIdx2 = activeIdx1 + symbolSamples - 1;
    signalFSK(activeIdx1:activeIdx2) = sin(2*pi*freqs(idx+1)*tSymbol);
end

%% 4) 跳频扩频
t1 = (0:100*pi/999:100*pi);
t2 = (0:110*pi/999:110*pi);
t3 = (0:120*pi/999:120*pi);
t4 = (0:130*pi/999:130*pi);
t5 = (0:140*pi/999:140*pi);
t6 = (0:150*pi/999:150*pi);
t7 = (0:160*pi/999:160*pi);
t8 = (0:170*pi/999:170*pi);
c1 = cos(t1); c2 = cos(t2); c3 = cos(t3); c4 = cos(t4);
c5 = cos(t5); c6 = cos(t6); c7 = cos(t7); c8 = cos(t8);

adr1 = Mcreate(seed);
adr1 = [adr1, adr1(1), adr1(2)];
fhSeq = zeros(1, ns);
for k = 1:ns
    fhSeq(k) = adr1(3*k-2)*2^2 + adr1(3*k-1)*2 + adr1(3*k);
end

carrierTable = {c8, c1, c2, c3, c4, c5, c6, c7};
spreadSignal = zeros(1, ns * frameSamples);
fhp = zeros(1, ns);
for k = 1:ns
    c = fhSeq(k);
    activeIdx1 = (k-1)*frameSamples + 1;
    activeIdx2 = activeIdx1 + symbolSamples - 1;
    carrierWave = carrierTable{c+1};
    carrierWave = carrierWave(:).';
    if numel(carrierWave) < symbolSamples
        carrierWave = repmat(carrierWave, 1, ceil(symbolSamples / numel(carrierWave)));
    end
    spreadSignal(activeIdx1:activeIdx2) = carrierWave(1:symbolSamples);
    fhp(k) = 500*c + 5000;
end

freqHoppedSig = signalFSK .* spreadSignal;

%% 5) 时延多径（可调）
if delay > 0
    s = [zeros(1, delay) freqHoppedSig(1:max(0, ns*frameSamples-delay))];
    s = s(1:ns*frameSamples);
    freqHoppedSig = freqHoppedSig + s;
end

%% 6) 多普勒频移（可调）
dopplerHz = opts.dopplerHz;
if abs(dopplerHz) > 1e-6
    t_total = (0:length(freqHoppedSig)-1) / fs;
    doppler_phase = exp(1j * 2 * pi * dopplerHz * t_total);
    freqHoppedSig = real(freqHoppedSig .* doppler_phase);
    doppler_applied = true;
else
    doppler_applied = false;
end

%% 7) AWGN 白噪声（由 snrDb 控制）
noisySignal = awgn(freqHoppedSig, snrDb, 1/2);

%% 8) 解扩 + LMS/低通
receiveSignal = noisySignal .* spreadSignal;
if opts.enableLMS
    muLMS = opts.lmsMu;
    filterLen = opts.lmsFilterLen;
    w = zeros(filterLen, 1);
    w(1) = 1;
    signalOut = zeros(1, length(receiveSignal));
    for n = filterLen:length(receiveSignal)
        x_vec = receiveSignal(n:-1:n-filterLen+1).';
        y_est = w' * x_vec;
        d_ref = receiveSignal(n);
        e = d_ref - y_est;
        normFactor = (x_vec' * x_vec) + 1e-8;
        w = w + (muLMS / normFactor) * e * x_vec;
        signalOut(n) = y_est;
    end
    signalOut(1:filterLen-1) = receiveSignal(1:filterLen-1);
else
    cofBand = fir1(64, 1000/fs);
    signalOut = filter(cofBand, 1, receiveSignal);
    signalOut = [signalOut(33:end), zeros(1, 32)];
end

%% 9) 频点判决（可选多普勒补偿扫描）
sentencedSymbol = zeros(1, ns);
uout = zeros(1, ns * frameSamples);
decisionMetricTrace = zeros(ns, 4);
softDecisions = zeros(ns, 4);

if opts.enableDopplerComp
    dopplerRange = opts.dopplerCompRange;
else
    dopplerRange = 0;
end

for n = 1:ns
    frameIdx1 = (n-1)*frameSamples + 1;
    frameActiveIdx2 = frameIdx1 + symbolSamples - 1;
    seg = signalOut(frameIdx1:frameActiveIdx2);

    maxEnergyOverDoppler = zeros(1, 4);
    candidateOutput = zeros(4, symbolSamples);

    for ii = 1:4
        fc = freqs(ii);
        bestEnergy = -inf;
        bestProjCos = 0;
        bestProjSin = 0;

        for dop = dopplerRange
            fcDoppler = fc + dop;
            refCos = cos(2*pi*fcDoppler*tSymbol);
            refSin = sin(2*pi*fcDoppler*tSymbol);
            projCos = sum(seg .* refCos);
            projSin = sum(seg .* refSin);
            energy = projCos^2 + projSin^2;
            if energy > bestEnergy
                bestEnergy = energy;
                bestProjCos = projCos;
                bestProjSin = projSin;
            end
        end

        maxEnergyOverDoppler(ii) = bestEnergy;
        candidateOutput(ii,:) = (bestProjCos / symbolSamples) * cos(2*pi*fc*tSymbol) + ...
                    (bestProjSin / symbolSamples) * sin(2*pi*fc*tSymbol);
    end

    [~, imax] = max(maxEnergyOverDoppler);
    sentencedSymbol(n) = imax;
    softDecisions(n, :) = maxEnergyOverDoppler;
    decisionMetricTrace(n, :) = maxEnergyOverDoppler;
    uout(frameIdx1:frameActiveIdx2) = candidateOutput(imax,:);
end

%% 10) 比特恢复（可选 Viterbi）
if opts.enableViterbi
    hardBits = zeros(1, numCodedBits);
    for n = 1:ns
        idx = sentencedSymbol(n) - 1;
        b1 = floor(idx / 2);
        b2 = mod(idx, 2);
        p1 = 2*n - 1;
        p2 = 2*n;
        if p1 <= numCodedBits
            hardBits(p1) = b1;
        end
        if p2 <= numCodedBits
            hardBits(p2) = b2;
        end
    end

    decoder = comm.ViterbiDecoder('TrellisStructure', poly2trellis(3, [7, 5]), ...
                                  'InputFormat', 'Hard', ...
                                  'TerminationMethod', 'Truncated');
    decodedBitsTemp = step(decoder, hardBits(:));
    decodedBits = decodedBitsTemp(1:g).';
else
    decodedBits = zeros(1, g);
    for i = 1:ns
        idx = sentencedSymbol(i) - 1;
        b1 = floor(idx / 2);
        b2 = mod(idx, 2);
        p1 = 2*i - 1;
        p2 = 2*i;
        if p1 <= g
            decodedBits(p1) = b1;
        end
        if p2 <= g
            decodedBits(p2) = b2;
        end
    end
end

%% 11) 统计与返回
bitErrors = sum(decodedBits ~= txBits);
symErrors = sum(sentencedSymbol ~= symbolMap);

result = struct();
result.g = g;
result.fs = fs;
result.snrDb = snrDb;
result.delay = delay;
result.dopplerHz = dopplerHz;
result.doppler_applied = doppler_applied;
result.enableDopplerComp = opts.enableDopplerComp;
result.enableLMS = opts.enableLMS;
result.enableViterbi = opts.enableViterbi;
result.txBits = txBits;
result.codedBits = codedBits;
result.signal1 = signal1;
result.SignalFSK = signalFSK;
result.spreadSignal = spreadSignal;
result.freqHoppedSig = freqHoppedSig;
result.noisySignal = noisySignal;
result.receiveSignal = receiveSignal;
result.signalOut = signalOut;
result.decodedBits = decodedBits;
result.ber = bitErrors / g;
result.ser = symErrors / ns;
result.symbolMap = symbolMap;
result.sentencedSymbol = sentencedSymbol;
result.uout = uout;
result.softDecisions = softDecisions;
result.residualEnergyTrace = decisionMetricTrace;
result.fhp = fhp;
result.opts = opts;
result.symbolDurationMs = opts.symbolDurationMs;
result.guardIntervalMs = opts.guardIntervalMs;
result.symbolSamples = symbolSamples;
result.guardSamples = guardSamples;
result.frameSamples = frameSamples;

%% 12) 可视化
if doPlots
    figure(1); clf;
    plot(signal1, 'b', 'LineWidth', 1); grid on;
    axis([-100 symbolSamples*g -1.5 1.5]);
    title('原始信源');

    figure(2); clf;
    plot(signalFSK);
    axis([-100 frameSamples*ns -3 3]);
    title('4-FSK信号');

    figure(3); clf;
    plot(fhp, 's', 'MarkerFaceColor', 'b', 'MarkerSize', 8);
    grid on;
    title('跳频图案');

    figure(4); clf;
    plot(freqHoppedSig);
    grid on;
    title(sprintf('跳频扩频信号 (Tsym=%.1fms, GI=%.1fms, delay=%d, doppler=%.1fHz, SNR=%.1fdB)', ...
        opts.symbolDurationMs, opts.guardIntervalMs, delay, dopplerHz, snrDb));

    figure(5); clf;
    subplot(2,1,1); plot(noisySignal); title('加噪后时域信号');
    subplot(2,1,2); Plot_f(noisySignal, fs); title('加噪后频谱');

    figure(6); clf;
    subplot(2,1,1); plot(signalOut); title('解扩/均衡后信号');
    subplot(2,1,2); Plot_f(signalOut, fs); title('解扩/均衡后频谱');
end
end

function opts = apply_default_opts(opts)
defaults = struct();
defaults.dopplerHz = 0;
defaults.enableDopplerComp = false;
defaults.dopplerCompRange = -50:10:50;
defaults.enableLMS = false;
defaults.enableViterbi = false;
defaults.lmsMu = 0.001;
defaults.lmsFilterLen = 32;
defaults.symbolDurationMs = 20;
defaults.guardIntervalMs = 30;
defaults.freqs = [9000 10000 11000 12000];

fns = fieldnames(defaults);
for i = 1:numel(fns)
    fn = fns{i};
    if ~isfield(opts, fn) || isempty(opts.(fn))
        opts.(fn) = defaults.(fn);
    end
end
end