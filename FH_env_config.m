function cfg = FH_env_config()
%FH_ENV_CONFIG Shared environment config for independent experiments.
% Reuse the same channel settings across BER/SER and sync-success tests.

cfg = struct();

% Base simulation settings
cfg.g = 200;
cfg.fs = 625000;
cfg.seed = 1001203;
cfg.doPlots = false;

% Reusable channel environment
cfg.snrDb = 40;       % AWGN level
cfg.delay = 0;        % delay (samples)
cfg.dopplerHz = 0;    % Doppler shift (Hz)

% Unified receiver options
cfg.opts = struct();
cfg.opts.dopplerHz = cfg.dopplerHz;
cfg.opts.enableDopplerComp = false;
cfg.opts.enableLMS = true;
cfg.opts.enableViterbi = false;
cfg.opts.symbolDurationMs = 20;
cfg.opts.guardIntervalMs = 30;
cfg.opts.dopplerCompRange = -50:10:50;
cfg.opts.lmsMu = 0.001;
cfg.opts.lmsFilterLen = 32;
end
