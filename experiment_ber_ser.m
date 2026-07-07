% BER/SER-only experiment (no sync metric mixed in)
clc;
clear;
close all;

cfg = FH_env_config();

snrVec = -50:5:-20;
numTrials = 3;

berVec = zeros(size(snrVec));
serVec = zeros(size(snrVec));

for i = 1:numel(snrVec)
    snrDb = snrVec(i);
    berAcc = 0;
    serAcc = 0;

    for t = 1:numTrials
        opts = cfg.opts;
        opts.dopplerHz = cfg.dopplerHz;
        opts.enableLMS = false;

        result = fhss_4fsk_simulate(cfg.g, cfg.fs, snrDb, cfg.delay, cfg.seed + t, cfg.doPlots, opts);

        berAcc = berAcc + result.ber;
        serAcc = serAcc + result.ser;
    end

    berVec(i) = berAcc / numTrials;
    serVec(i) = serAcc / numTrials;
end

figure('Name', 'BER/SER Only', 'NumberTitle', 'off');
semilogy(snrVec, berVec, 'o-', 'LineWidth', 1.5);
hold on;
semilogy(snrVec, serVec, 's-', 'LineWidth', 1.5);
grid on;
xlabel('SNR (dB)');
ylabel('Error Rate');
title('BER/SER Experiment (Sync Success Not Included)');
legend('BER', 'SER', 'Location', 'southwest');

disp(table(snrVec(:), berVec(:), serVec(:), ...
    'VariableNames', {'SNR_dB', 'BER', 'SER'}));
