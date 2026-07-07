% Thesis figure suite for FHSS+4FSK experiments
% Generates core plots for a master's thesis:
% 1) BER/SER vs SNR for multiple receiver configurations
% 2) Ablation bar chart at a representative SNR point
% 3) BER heatmaps over SNR-Doppler (with and without Doppler compensation)
% 4) Runtime comparison per configuration
% 5) Spectrum snapshots along the transceiver chain
% 6) Time-domain chain snapshots

clc;
clear;
close all;

cfg = FH_env_config();
cfg.doPlots = false;

% -----------------------------
% Experiment profile
% -----------------------------
quickMode = true;  % Set false for paper-grade denser sweeps

if quickMode
    snrVec = -50:5:-20;
    numTrialsMain = 3;
    numTrialsHeat = 2;
    dopplerVec = 0:20:100;
else
    snrVec = -55:2:-15;
    numTrialsMain = 10;
    numTrialsHeat = 5;
    dopplerVec = 0:10:120;
end

refSnrForAblation = -30;
mainDopplerHz = 0;

% If Communications Toolbox is unavailable, skip Viterbi-related cases.
hasComm = ~isempty(which('comm.ConvolutionalEncoder')) && ~isempty(which('comm.ViterbiDecoder'));

caseDefs = build_case_defs(hasComm);
numCases = numel(caseDefs);

% Result directory
outDir = fullfile(pwd, 'results_thesis_figs');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end

% -----------------------------
% 1) BER/SER vs SNR curves
% -----------------------------
berMat = zeros(numCases, numel(snrVec));
serMat = zeros(numCases, numel(snrVec));

fprintf('Running BER/SER sweeps...\n');
for c = 1:numCases
    fprintf('  Case: %s\n', caseDefs(c).name);
    for i = 1:numel(snrVec)
        snrDb = snrVec(i);
        berAcc = 0;
        serAcc = 0;

        for t = 1:numTrialsMain
            opts = cfg.opts;
            opts = apply_case(opts, caseDefs(c));
            opts.dopplerHz = mainDopplerHz;

            result = fhss_4fsk_simulate(cfg.g, cfg.fs, snrDb, cfg.delay, cfg.seed + t, false, opts);
            berAcc = berAcc + result.ber;
            serAcc = serAcc + result.ser;
        end

        berMat(c, i) = berAcc / numTrialsMain;
        serMat(c, i) = serAcc / numTrialsMain;
    end
end

fig1 = figure('Name', 'Thesis Fig 1: BER/SER Curves', 'NumberTitle', 'off', 'Color', 'w');
subplot(2,1,1);
hold on;
for c = 1:numCases
    semilogy(snrVec, max(berMat(c, :), 1e-4), '-o', 'LineWidth', 1.4, 'DisplayName', caseDefs(c).name);
end
grid on;
xlabel('SNR (dB)');
ylabel('BER');
title('BER vs SNR');
subtitle(sprintf('Doppler = %d Hz', mainDopplerHz));
legend('Location', 'southwest');

subplot(2,1,2);
hold on;
for c = 1:numCases
    semilogy(snrVec, max(serMat(c, :), 1e-4), '-s', 'LineWidth', 1.4, 'DisplayName', caseDefs(c).name);
end
grid on;
xlabel('SNR (dB)');
ylabel('SER');
title('SER vs SNR');
subtitle(sprintf('Doppler = %d Hz', mainDopplerHz));
legend('Location', 'southwest');

saveas(fig1, fullfile(outDir, 'fig1_ber_ser_curves.png'));

% Save curve table
curveRows = {};
for c = 1:numCases
    for i = 1:numel(snrVec)
        curveRows(end+1, :) = {caseDefs(c).name, snrVec(i), berMat(c, i), serMat(c, i)}; %#ok<AGROW>
    end
end
curveTbl = cell2table(curveRows, 'VariableNames', {'Case', 'SNR_dB', 'BER', 'SER'});
writetable(curveTbl, fullfile(outDir, 'table_ber_ser_curves.csv'));

% -----------------------------
% 2) Ablation bar chart
% -----------------------------
[~, refIdx] = min(abs(snrVec - refSnrForAblation));
berAbl = berMat(:, refIdx);
serAbl = serMat(:, refIdx);

fig2 = figure('Name', 'Thesis Fig 2: Ablation', 'NumberTitle', 'off', 'Color', 'w');
subplot(2,1,1);
bar(berAbl);
grid on;
set(gca, 'XTick', 1:numCases, 'XTickLabel', {caseDefs.name}, 'XTickLabelRotation', 20);
ylabel('BER');
title(sprintf('Ablation BER @ SNR = %d dB, Doppler = %d Hz', snrVec(refIdx), mainDopplerHz));

subplot(2,1,2);
bar(serAbl);
grid on;
set(gca, 'XTick', 1:numCases, 'XTickLabel', {caseDefs.name}, 'XTickLabelRotation', 20);
ylabel('SER');
title(sprintf('Ablation SER @ SNR = %d dB, Doppler = %d Hz', snrVec(refIdx), mainDopplerHz));

saveas(fig2, fullfile(outDir, 'fig2_ablation_bars.png'));

ablationTbl = table(string({caseDefs.name}).', repmat(snrVec(refIdx), numCases, 1), berAbl, serAbl, ...
    'VariableNames', {'Case', 'SNR_dB', 'BER', 'SER'});
writetable(ablationTbl, fullfile(outDir, 'table_ablation.csv'));

% -----------------------------
% 3) SNR-Doppler BER heatmaps
% -----------------------------
fprintf('Running BER heatmaps...\n');
heatBase = zeros(numel(dopplerVec), numel(snrVec));
heatComp = zeros(numel(dopplerVec), numel(snrVec));

for d = 1:numel(dopplerVec)
    dopplerHz = dopplerVec(d);
    for i = 1:numel(snrVec)
        snrDb = snrVec(i);

        b0 = 0;
        b1 = 0;
        for t = 1:numTrialsHeat
            opts0 = cfg.opts;
            opts0.enableLMS = false;
            opts0.enableViterbi = false;
            opts0.enableDopplerComp = false;
            opts0.dopplerHz = dopplerHz;

            r0 = fhss_4fsk_simulate(cfg.g, cfg.fs, snrDb, cfg.delay, cfg.seed + 1000 + t, false, opts0);
            b0 = b0 + r0.ber;

            opts1 = opts0;
            opts1.enableDopplerComp = true;
            r1 = fhss_4fsk_simulate(cfg.g, cfg.fs, snrDb, cfg.delay, cfg.seed + 2000 + t, false, opts1);
            b1 = b1 + r1.ber;
        end

        heatBase(d, i) = b0 / numTrialsHeat;
        heatComp(d, i) = b1 / numTrialsHeat;
    end
end

fig3 = figure('Name', 'Thesis Fig 3: SNR-Doppler Heatmaps', 'NumberTitle', 'off', 'Color', 'w');
subplot(1,2,1);
imagesc(snrVec, dopplerVec, heatBase);
set(gca, 'YDir', 'normal');
colorbar;
xlabel('SNR (dB)');
ylabel('Doppler (Hz)');
title('BER Heatmap (No Doppler Comp)');

subplot(1,2,2);
imagesc(snrVec, dopplerVec, heatComp);
set(gca, 'YDir', 'normal');
colorbar;
xlabel('SNR (dB)');
ylabel('Doppler (Hz)');
title('BER Heatmap (With Doppler Comp)');

saveas(fig3, fullfile(outDir, 'fig3_snr_doppler_heatmaps.png'));

[ss, dd] = meshgrid(snrVec, dopplerVec);
heatTbl = table(ss(:), dd(:), heatBase(:), heatComp(:), ...
    'VariableNames', {'SNR_dB', 'Doppler_Hz', 'BER_Base', 'BER_DopplerComp'});
writetable(heatTbl, fullfile(outDir, 'table_heatmap.csv'));

% -----------------------------
% 4) Runtime comparison
% -----------------------------
fprintf('Running runtime benchmark...\n');
runtimeSec = zeros(numCases, 1);

for c = 1:numCases
    opts = cfg.opts;
    opts = apply_case(opts, caseDefs(c));
    opts.dopplerHz = mainDopplerHz;

    tic;
    fhss_4fsk_simulate(cfg.g, cfg.fs, refSnrForAblation, cfg.delay, cfg.seed + 3000 + c, false, opts);
    runtimeSec(c) = toc;
end

fig4 = figure('Name', 'Thesis Fig 4: Runtime', 'NumberTitle', 'off', 'Color', 'w');
bar(runtimeSec);
grid on;
set(gca, 'XTick', 1:numCases, 'XTickLabel', {caseDefs.name}, 'XTickLabelRotation', 20);
ylabel('Runtime (s)');
title(sprintf('Single-run Runtime @ SNR = %d dB, Doppler = %d Hz', refSnrForAblation, mainDopplerHz));

saveas(fig4, fullfile(outDir, 'fig4_runtime.png'));

runtimeTbl = table(string({caseDefs.name}).', runtimeSec, ...
    'VariableNames', {'Case', 'Runtime_s'});
writetable(runtimeTbl, fullfile(outDir, 'table_runtime.csv'));

% -----------------------------
% 5) Spectrum snapshots
% -----------------------------
fprintf('Running spectrum/time-chain snapshots...\n');
snapshotSNR = refSnrForAblation;
snapshotDoppler = 50;

snapshotOpts = cfg.opts;
snapshotOpts.enableLMS = false;
snapshotOpts.enableViterbi = false;
snapshotOpts.enableDopplerComp = true;
snapshotOpts.dopplerHz = snapshotDoppler;

snapshotResult = fhss_4fsk_simulate(cfg.g, cfg.fs, snapshotSNR, cfg.delay, cfg.seed + 9000, false, snapshotOpts);

[f1, p1] = calc_psd(snapshotResult.SignalFSK, cfg.fs);
[f2, p2] = calc_psd(snapshotResult.freqHoppedSig, cfg.fs);
[f3, p3] = calc_psd(snapshotResult.noisySignal, cfg.fs);
[f4, p4] = calc_psd(snapshotResult.signalOut, cfg.fs);

fig5 = figure('Name', 'Thesis Fig 5: Spectrum Snapshots', 'NumberTitle', 'off', 'Color', 'w');
subplot(2,2,1); plot(f1, p1, 'LineWidth', 1.2); grid on; title('TX 4FSK Spectrum'); xlabel('Frequency (Hz)'); ylabel('PSD');
subplot(2,2,2); plot(f2, p2, 'LineWidth', 1.2); grid on; title('FH Spread Spectrum'); xlabel('Frequency (Hz)'); ylabel('PSD');
subplot(2,2,3); plot(f3, p3, 'LineWidth', 1.2); grid on; title('After Channel+Noise Spectrum'); xlabel('Frequency (Hz)'); ylabel('PSD');
subplot(2,2,4); plot(f4, p4, 'LineWidth', 1.2); grid on; title('Post Receiver Spectrum'); xlabel('Frequency (Hz)'); ylabel('PSD');
sgtitle(sprintf('Spectrum Chain @ SNR=%d dB, Doppler=%d Hz', snapshotSNR, snapshotDoppler));

saveas(fig5, fullfile(outDir, 'fig5_spectrum_chain.png'));

% -----------------------------
% 6) Time-domain chain snapshots
% -----------------------------
showFrames = 6;
showLen = min(showFrames * snapshotResult.frameSamples, numel(snapshotResult.SignalFSK));
tAxis = (0:showLen-1) / cfg.fs;

fig6 = figure('Name', 'Thesis Fig 6: Time-Domain Chain', 'NumberTitle', 'off', 'Color', 'w');
subplot(4,1,1); plot(tAxis, snapshotResult.SignalFSK(1:showLen), 'LineWidth', 1); grid on; ylabel('Amp'); title('TX 4FSK (Time Domain)');
subplot(4,1,2); plot(tAxis, snapshotResult.freqHoppedSig(1:showLen), 'LineWidth', 1); grid on; ylabel('Amp'); title('FH Spread Output');
subplot(4,1,3); plot(tAxis, snapshotResult.noisySignal(1:showLen), 'LineWidth', 1); grid on; ylabel('Amp'); title('After Channel+Noise');
subplot(4,1,4); plot(tAxis, snapshotResult.signalOut(1:showLen), 'LineWidth', 1); grid on; ylabel('Amp'); xlabel('Time (s)'); title('Post Receiver Processing');
sgtitle(sprintf('Time-Domain Chain (First %d Frames)', showFrames));

saveas(fig6, fullfile(outDir, 'fig6_time_domain_chain.png'));

save(fullfile(outDir, 'raw_results.mat'), 'snrVec', 'dopplerVec', 'berMat', 'serMat', 'heatBase', 'heatComp', 'runtimeSec', 'caseDefs', 'mainDopplerHz', ...
    'snapshotSNR', 'snapshotDoppler', 'snapshotResult');

fprintf('\nDone. Outputs saved to: %s\n', outDir);

function cases = build_case_defs(hasComm)
cases = struct('name', {}, 'enableDopplerComp', {}, 'enableLMS', {}, 'enableViterbi', {});

cases(1) = struct('name', 'Baseline', 'enableDopplerComp', false, 'enableLMS', false, 'enableViterbi', false);
cases(2) = struct('name', 'DopplerComp', 'enableDopplerComp', true, 'enableLMS', false, 'enableViterbi', false);
cases(3) = struct('name', 'LMS', 'enableDopplerComp', false, 'enableLMS', true, 'enableViterbi', false);

if hasComm
    cases(4) = struct('name', 'Viterbi', 'enableDopplerComp', false, 'enableLMS', false, 'enableViterbi', true);
    cases(5) = struct('name', 'AllOn', 'enableDopplerComp', true, 'enableLMS', true, 'enableViterbi', true);
else
    cases(4) = struct('name', 'AllOn_NoVit', 'enableDopplerComp', true, 'enableLMS', true, 'enableViterbi', false);
end
end

function opts = apply_case(opts, c)
opts.enableDopplerComp = c.enableDopplerComp;
opts.enableLMS = c.enableLMS;
opts.enableViterbi = c.enableViterbi;
end

function [fAxis, pxx] = calc_psd(x, fs)
nfft = 2^nextpow2(max(1024, numel(x)));
X = fft(x, nfft);
px = (X .* conj(X)) / nfft;
pxx = real(px(1:nfft/2+1));
fAxis = fs * (0:nfft/2) / nfft;
end
