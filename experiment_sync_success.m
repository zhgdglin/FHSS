% Sync-success-only experiment (separate from BER/SER)
clc;
clear;
close all;

cfg = FH_env_config();

snrVec = 0:2:20;
numTrials = 30;
maxPreOffset = round(0.8 * cfg.fs * 0.05); % up to 80%% of one 50ms frame
tolSamples = round(0.001 * cfg.fs);         % 1ms tolerance

successRate = zeros(size(snrVec));

for i = 1:numel(snrVec)
    snrDb = snrVec(i);
    ok = 0;

    for t = 1:numTrials
        opts = cfg.opts;
        opts.dopplerHz = cfg.dopplerHz;

        result = fhss_4fsk_simulate(
            cfg.g, cfg.fs, snrDb, cfg.delay, cfg.seed + t, false, opts);

        % Inject unknown start offset for synchronization testing.
        preOffset = randi([0, maxPreOffset], 1, 1);
        rx = [zeros(1, preOffset), result.noisySignal];

        estStart = estimate_symbol_start_by_energy(rx, result.symbolSamples, result.guardSamples);
        trueStart = preOffset + 1;

        if abs(estStart - trueStart) <= tolSamples
            ok = ok + 1;
        end
    end

    successRate(i) = ok / numTrials;
end

figure('Name', 'Sync Success Only', 'NumberTitle', 'off');
plot(snrVec, successRate, 'o-', 'LineWidth', 1.6);
grid on;
xlabel('SNR (dB)');
ylabel('Synchronization Success Rate');
title('Sync Success Experiment (BER/SER Not Included)');
ylim([0 1]);

disp(table(snrVec(:), successRate(:), ...
    'VariableNames', {'SNR_dB', 'SyncSuccessRate'}));

function estStart = estimate_symbol_start_by_energy(rx, symbolSamples, guardSamples)
% A lightweight timing detector based on active-vs-guard energy contrast.

frameSamples = symbolSamples + guardSamples;
numFrames = floor(length(rx) / frameSamples);
maxOffset = frameSamples - 1;

if numFrames < 1
    estStart = 1;
    return;
end

score = -inf(1, maxOffset + 1);

for off = 0:maxOffset
    s = 0;
    for k = 0:(numFrames - 1)
        base = off + k * frameSamples + 1;
        idxActive = base:(base + symbolSamples - 1);
        idxGuard = (base + symbolSamples):(base + frameSamples - 1);

        if idxGuard(end) > length(rx)
            break;
        end

        eActive = sum(rx(idxActive) .^ 2);
        eGuard = sum(rx(idxGuard) .^ 2);
        s = s + (eActive - eGuard);
    end
    score(off + 1) = s;
end

[~, bestOff] = max(score);
estStart = bestOff;
end
