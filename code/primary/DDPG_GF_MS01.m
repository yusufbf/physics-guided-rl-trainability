%% ========================================================================
%  GENERIC-FIXED (GF) BASELINE v1.0
%  Primary comparator for the frozen PG-vs-GF protocol.
%  Prepared before execution of GF runs; no performance retuning allowed.
%  GF manipulations: constant desired speed, fixed warning clearance,
%  fixed training target radius/arrival speed, and fixed 300-step horizon.
%
%  DDPG_Quadcopter_RLToolbox_v13_6_GoalFrameControl.m
%  DDPG v13.6 - Goal-Frame Action and Observation Representation
%
%  PERUBAHAN UTAMA DARI V13.5:
%  1. Action agent dinyatakan pada kerangka relatif target:
%       action(1) = percepatan parallel terhadap arah target
%       action(2) = percepatan lateral terhadap arah target
%  2. Action goal-frame ditransformasikan ke percepatan dunia sebelum
%     integrasi dinamika.
%  3. Observation dibuat rotation-invariant menggunakan jarak target,
%     kecepatan radial/lateral, obstacle bearing relatif, dan jarak
%     boundary sepanjang empat arah goal-frame.
%  4. Action-change penalty dihitung dari perintah percepatan dunia agar
%     perubahan basis goal-frame tidak menyamarkan perubahan kendali.
%  5. Logging membedakan action goal-frame dan world command.
%  6. Interior-target curriculum, terminal capture, reward, noise, dan
%     stage-specific horizon V13.5 dipertahankan.
%
%  MODE:
%  - "smoke" : pemeriksaan struktur kode (sangat singkat)
%  - "pilot" : eksperimen diagnosis dengan anggaran moderat
%  - "train" : eksperimen penuh berbasis mastery curriculum
%  ========================================================================

clear; clc; close all;

%% ========================================================================
%  BAGIAN 1: EXECUTION MODE DAN REPRODUCIBILITY
%  ========================================================================

execution.mode = "pilot";   % "smoke", "pilot", atau "train"
execution.masterSeed = 13301;
execution.environmentSeed = 23301;
execution.validationSeed = 33301;
execution.selectionSeed = 43301;
execution.testSeed = 53301;
execution.multiSeedRun = 1;  % paired replicate identifier

rng(execution.masterSeed, 'twister');

fprintf('=================================================================\n');
fprintf(' DDPG QUADCOPTER V13.6 GF | MODE: %s\n', upper(execution.mode));
fprintf(' GF MULTI-SEED REPLICATE: MS01 | master=%d | env=%d\n', execution.masterSeed, execution.environmentSeed);
fprintf(' Goal-Frame Control + Interior-Target Curriculum\n');
fprintf('=================================================================\n\n');

%% ========================================================================
%  BAGIAN 2: KONFIGURASI FISIK, MISI, DAN PETA
%  ========================================================================

config.env.xMin = 0;
config.env.xMax = 20;
config.env.yMin = 0;
config.env.yMax = 20;

config.quad.mass = 1.0;
config.quad.maxVelocity = 2.0;
config.quad.maxAcceleration = 1.0;
config.quad.dt = 0.1;
config.quad.radius = 0.3;

config.mission.nominalStart = [1; 1];
config.mission.finalTarget = [18; 18];
config.mission.defaultTargetRadius = 0.5;
config.mission.defaultArrivalSpeed = 0.5;
config.mission.defaultMaxSteps = 300;

% Frozen comparator identity (PG-vs-GF protocol v1.0)
config.experiment.methodTag = "GF";
config.experiment.configTag = "V13_6_GF";
config.experiment.runLabel = "DDPG_v13_6_GF_MS01";
config.experiment.protocol = "PG_vs_GF_v1_0";

% Peta baseline V9/V13 dipertahankan.
config.map.obstacles = [
     5,  5, 1.5;
    10,  8, 2.0;
    15, 12, 1.5;
     8, 14, 1.8;
    12,  5, 1.2;
     3, 12, 1.0;
    16,  6, 1.3;
     7,  2, 0.8;
    14, 17, 1.0;
     2,  7, 0.9
];

config.derived.worldSize = [config.env.xMax-config.env.xMin; ...
                            config.env.yMax-config.env.yMin];
config.derived.maxDistance = norm(config.derived.worldSize);
config.derived.nominalDirectDistance = norm( ...
    config.mission.finalTarget-config.mission.nominalStart);

% Lower bound waktu dengan fase akselerasi, tanpa syarat berhenti di target.
tAccel = config.quad.maxVelocity/config.quad.maxAcceleration;
dAccel = 0.5*config.quad.maxAcceleration*tAccel^2;
if config.derived.nominalDirectDistance > dAccel
    tMinimum = tAccel + ...
        (config.derived.nominalDirectDistance-dAccel)/config.quad.maxVelocity;
else
    tMinimum = sqrt(2*config.derived.nominalDirectDistance/ ...
        config.quad.maxAcceleration);
end
config.derived.minimumStepsAccelerationAware = ceil(tMinimum/config.quad.dt);

fprintf('Nominal direct distance        : %.2f m\n', ...
    config.derived.nominalDirectDistance);
fprintf('Acceleration-aware lower bound : %d steps\n', ...
    config.derived.minimumStepsAccelerationAware);
fprintf('Episode horizon                : %d steps\n\n', ...
    config.mission.defaultMaxSteps);

%% ========================================================================
%  BAGIAN 3: REWARD V13.6 - TERMINAL CAPTURE (DIPERTAHANKAN)
%  ========================================================================

config.reward.goal = 500;
config.reward.collision = -300;
config.reward.boundary = -300;
config.reward.timeout = -75;

config.reward.step = -0.20;
config.reward.progressScale = 10.0;
config.reward.distanceScale = 1.0;
config.reward.proximityScale = 3.0;
config.reward.boundaryWarningScale = 2.0;
config.reward.actionEffortScale = 0.05;
config.reward.actionChangeScale = 0.05;
config.reward.overspeedScale = 2.0;
config.reward.lateralVelocityScale = 0.50;

config.safety.baseClearance = 0.50;
config.safety.maxWarningClearance = 2.50;
config.safety.boundaryWarningDistance = 1.00;
config.safety.startClearanceMargin = 0.50;
config.safety.startBoundaryMargin = 0.80;
config.safety.observationClearanceScale = 4.00;

config.mastery.actionSaturationThreshold = 0.95;

%% ========================================================================
%  BAGIAN 4: INTERIOR-TARGET + TERMINAL-CAPTURE CURRICULUM
%  ========================================================================

% samplingMode = "polar" memakai [dMin dMax angleMinDeg angleMaxDeg]
% samplingMode = "region" memakai [xMin xMax yMin yMax].
%
% Target interior dipakai pada Stage 1-3 agar agent mempelajari arah target
% dan pengereman tanpa dominasi boundary failure. Target kemudian dipindah
% secara bertahap menuju target final [18;18].

stages(1) = makeStageV136(1, "InteriorEasy-0", [0], ...
    [10;10], "polar", [1.5 3.0 0 360], ...
    1.50, 1.50, 100, 0.80, 0.80);

stages(2) = makeStageV136(2, "InteriorCapture-0", [0], ...
    [10;10], "polar", [2.0 4.0 0 360], ...
    1.00, 1.00, 120, 0.80, 0.80);

stages(3) = makeStageV136(3, "InteriorPrecise-0", [0], ...
    [10;10], "polar", [3.0 6.0 0 360], ...
    0.75, 0.75, 150, 0.75, 0.80);

stages(4) = makeStageV136(4, "TargetTransfer-14-0", [0], ...
    [14;14], "polar", [3.0 6.0 0 360], ...
    0.75, 0.75, 180, 0.70, 0.85);

stages(5) = makeStageV136(5, "TargetTransfer-18-0", [0], ...
    [18;18], "polar", [2.5 5.0 15 75], ...
    1.00, 1.00, 180, 0.70, 0.85);

stages(6) = makeStageV136(6, "FullRange-0", [0], ...
    [18;18], "region", [0.8 3.0 0.8 3.0], ...
    0.50, 0.50, 300, 0.65, 0.85);

stages(7) = makeStageV136(7, "Basic-0-2-4", [0 2 4], ...
    [18;18], "region", [0.8 3.0 0.8 3.0], ...
    0.50, 0.50, 300, 0.60, 0.85);

stages(8) = makeStageV136(8, "Moderate-2-4-6", [2 4 6], ...
    [18;18], "region", [0.8 3.0 0.8 3.0], ...
    0.50, 0.50, 300, 0.60, 0.90);

stages(9) = makeStageV136(9, "Dense-4-6-8", [4 6 8], ...
    [18;18], "region", [0.8 3.0 0.8 3.0], ...
    0.50, 0.50, 300, 0.60, 0.90);

stages(10) = makeStageV136(10, "Final-6-8-10", [6 8 10], ...
    [18;18], "region", [0.8 3.0 0.8 3.0], ...
    0.50, 0.50, 300, 0.60, 0.90);

% ------------------------------------------------------------------------
% GENERIC-FIXED training settings (frozen before GF execution)
% Same curriculum topology and scenario distributions as PG, but
% terminal relaxation and stage-specific horizon are removed.
for gfStageIdx = 1:numel(stages)
    stages(gfStageIdx).targetRadius = 0.50;
    stages(gfStageIdx).arrivalSpeed = 0.50;
    stages(gfStageIdx).maxSteps = 300;
end

config.curriculum.randomizeObstacleSubset = true;
config.curriculum.allowForcedAdvance = false;
config.curriculum.restoreBestCheckpointEachStage = true;
config.curriculum.numStages = numel(stages);

switch execution.mode
    case "smoke"
        episodesPerBlock = [2 2 2 2 2 2 2 2 2 2];
        maxBlocksPerStage = [1 1 1 1 1 1 1 1 1 1];
        validationScenariosPerStage = [3 3 3 3 3 3 3 3 3 3];
        config.curriculum.allowForcedAdvance = true;

    case "pilot"
        episodesPerBlock = [120 140 170 190 220 260 280 320 360 400];
        maxBlocksPerStage = [5 5 5 4 4 4 4 4 4 4];
        validationScenariosPerStage = [24 24 24 24 24 30 30 36 40 48];

    case "train"
        episodesPerBlock = [200 240 300 340 400 480 540 620 720 820];
        maxBlocksPerStage = [6 6 6 5 5 5 5 5 5 6];
        validationScenariosPerStage = [40 40 40 40 40 50 60 70 80 100];

    otherwise
        error('execution.mode harus "smoke", "pilot", atau "train".');
end

for sIdx = 1:numel(stages)
    stages(sIdx).episodesPerBlock = episodesPerBlock(sIdx);
    stages(sIdx).maxBlocks = maxBlocksPerStage(sIdx);
    stages(sIdx).numValidationScenarios = ...
        validationScenariosPerStage(sIdx);

    if execution.mode == "smoke"
        stages(sIdx).maxSteps = min(stages(sIdx).maxSteps, 40);
    end
end

%% ========================================================================
%  BAGIAN 5: OUTPUT DAN TEST SETTINGS
%  ========================================================================

config.output.rootDirectory = fullfile('Outputs','DDPG_v13_6_GF_MS01_Output');
config.output.checkpointDirectory = fullfile( ...
    config.output.rootDirectory, 'checkpoints');

if execution.mode == "smoke"
    config.test.numScenariosFinal10 = 5;
    config.test.numScenariosPerStage = 2;
else
    config.test.numScenariosFinal10 = 100;
    config.test.numScenariosPerStage = 20;
end

prepareOutputDirectoryV136(config.output.rootDirectory, ...
    config.output.checkpointDirectory);

%% ========================================================================
%  BAGIAN 6: GOAL-FRAME OBSERVATION DAN ACTION SPECIFICATION
%  ========================================================================

% Observation V13.6 (14 komponen):
%  1  normalized target distance
%  2  radial velocity / maxVelocity (positif menuju target)
%  3  lateral velocity / maxVelocity
%  4  normalized nearest-obstacle clearance
%  5  cos(relative obstacle bearing)
%  6  sin(relative obstacle bearing)
%  7  obstacle closing speed / maxVelocity
%  8  forward boundary ray distance / maxDistance
%  9  backward boundary ray distance / maxDistance
% 10  left boundary ray distance / maxDistance
% 11  right boundary ray distance / maxDistance
% 12  target radius / 2
% 13  arrival-speed limit / maxVelocity
% 14  braking-aware desired speed / maxVelocity
%
% Action V13.6:
%  action(1) = normalized parallel acceleration command
%  action(2) = normalized lateral acceleration command

numObservations = 14;
numActions = 2;

obsInfo = rlNumericSpec([numObservations 1], ...
    'LowerLimit', -ones(numObservations,1), ...
    'UpperLimit',  ones(numObservations,1));
obsInfo.Name = 'Rotation-invariant goal-frame navigation observation';

actInfo = rlNumericSpec([numActions 1], ...
    'LowerLimit', -ones(numActions,1), ...
    'UpperLimit',  ones(numActions,1));
actInfo.Name = 'Normalized goal-frame acceleration command';

%% ========================================================================
%  BAGIAN 7: RUNTIME DAN ENVIRONMENT
%  ========================================================================

global DDPG_V136_RUNTIME;
DDPG_V136_RUNTIME = initializeRuntimeV136(config, execution, stages);

stepHandle = @(action, loggedSignals) ...
    quadcopterStepV136(action, loggedSignals, config);
resetHandle = @() quadcopterResetV136(config);
env = rlFunctionEnv(obsInfo, actInfo, stepHandle, resetHandle);

% Beberapa versi toolbox melakukan reset saat rlFunctionEnv dibuat.
% Hapus seluruh efek reset konstruksi sebelum training dimulai.
DDPG_V136_RUNTIME = initializeRuntimeV136(config, execution, stages);

%% ========================================================================
%  BAGIAN 8: ACTOR DAN CRITIC UNTUK GOAL-FRAME POLICY
%  ========================================================================

actorNetwork = [
    featureInputLayer(numObservations, 'Normalization','none', 'Name','state')
    fullyConnectedLayer(400, 'Name','actor_fc1')
    reluLayer('Name','actor_relu1')
    fullyConnectedLayer(300, 'Name','actor_fc2')
    reluLayer('Name','actor_relu2')
    fullyConnectedLayer(numActions, 'Name','actor_output', ...
        'WeightsInitializer','narrow-normal', ...
        'BiasInitializer','zeros')
    tanhLayer('Name','actor_tanh')
];
actorNetwork = dlnetwork(actorNetwork);
actor = rlContinuousDeterministicActor(actorNetwork, obsInfo, actInfo);

statePath = [
    featureInputLayer(numObservations, 'Normalization','none', 'Name','state')
    fullyConnectedLayer(400, 'Name','critic_state_fc1')
    reluLayer('Name','critic_state_relu1')
];

actionPath = [
    featureInputLayer(numActions, 'Normalization','none', 'Name','action')
    fullyConnectedLayer(400, 'Name','critic_action_fc1')
    reluLayer('Name','critic_action_relu1')
];

commonPath = [
    additionLayer(2, 'Name','critic_add')
    fullyConnectedLayer(300, 'Name','critic_fc2')
    reluLayer('Name','critic_relu2')
    fullyConnectedLayer(1, 'Name','qvalue')
];

criticGraph = layerGraph(statePath);
criticGraph = addLayers(criticGraph, actionPath);
criticGraph = addLayers(criticGraph, commonPath);
criticGraph = connectLayers(criticGraph, ...
    'critic_state_relu1', 'critic_add/in1');
criticGraph = connectLayers(criticGraph, ...
    'critic_action_relu1', 'critic_add/in2');
criticNetwork = dlnetwork(criticGraph);

critic = rlQValueFunction(criticNetwork, obsInfo, actInfo, ...
    'ObservationInputNames','state', ...
    'ActionInputNames','action');

%% ========================================================================
%  BAGIAN 9: DDPG OPTIONS DENGAN NOISE LEBIH RENDAH
%  ========================================================================

config.agent.discountFactor = 0.99;
config.agent.bufferLength = 1e6;
config.agent.miniBatchSize = 512;
config.agent.actorLearningRate = 1e-4;
config.agent.criticLearningRate = 2e-4;
config.agent.targetSmoothFactor = 1e-3;
config.agent.gradientThreshold = 1.0;
config.agent.explorationInitialStd = 0.20;
config.agent.explorationDecayRate = 1e-5;
config.agent.explorationMinimumStd = 0.03;

agentOptions = rlDDPGAgentOptions;
agentOptions.SampleTime = config.quad.dt;
agentOptions.DiscountFactor = config.agent.discountFactor;
agentOptions.ExperienceBufferLength = config.agent.bufferLength;
agentOptions.MiniBatchSize = config.agent.miniBatchSize;
agentOptions.TargetSmoothFactor = config.agent.targetSmoothFactor;
agentOptions.TargetUpdateFrequency = 1;

agentOptions.ActorOptimizerOptions = rlOptimizerOptions( ...
    'LearnRate', config.agent.actorLearningRate, ...
    'GradientThreshold', config.agent.gradientThreshold);
agentOptions.CriticOptimizerOptions = rlOptimizerOptions( ...
    'LearnRate', config.agent.criticLearningRate, ...
    'GradientThreshold', config.agent.gradientThreshold);
agentOptions = setDDPGNoiseOptionsV136(agentOptions, config.agent, numActions);

agent = rlDDPGAgent(actor, critic, agentOptions);

%% ========================================================================
%  BAGIAN 10: TRAINING RECORDS
%  ========================================================================

trainingHistory = cell(config.curriculum.numStages, max(maxBlocksPerStage));
stageLog = initializeStageLogV136();
stageBestLog = initializeStageBestLogV136();
checkpointFiles = strings(0,1);
stageCheckpointFiles = cell(config.curriculum.numStages,1);
stageValidationBanks = cell(config.curriculum.numStages,1);
stageCandidateTables = cell(config.curriculum.numStages,1);
for sIdx = 1:config.curriculum.numStages
    stageCheckpointFiles{sIdx} = strings(0,1);
end

stageMasteredFlags = false(config.curriculum.numStages,1);
highestAttemptedStage = 0;
highestMasteredStage = 0;
trainingStart = tic;
stopCurriculum = false;

%% ========================================================================
%  BAGIAN 11: STAGE-BASED TRAINING DAN STAGE-AWARE RESTORE
%  ========================================================================

fprintf('Curriculum stages: %d\n', config.curriculum.numStages);
fprintf('Forced advance   : %s\n\n', string(config.curriculum.allowForcedAdvance));

for stageIndex = 1:config.curriculum.numStages
    stage = stages(stageIndex);
    stageMastered = false;
    highestAttemptedStage = stageIndex;

    fprintf('\n===============================================================\n');
    fprintf(' STAGE %d/%d: %s\n', stageIndex, ...
        config.curriculum.numStages, stage.name);
    fprintf(' Target          : [%.2f %.2f]\n', ...
        stage.target(1), stage.target(2));
    fprintf(' Obstacles       : %s\n', mat2str(stage.allowedObstacleCounts));
    fprintf(' Start sampling  : %s | %s\n', ...
        stage.samplingMode, mat2str(stage.samplingSpec));
    fprintf([' Capture target  : radius %.2f m | arrival speed %.2f m/s | ' ...
        'horizon %d\n'], ...
        stage.targetRadius, stage.arrivalSpeed, stage.maxSteps);
    fprintf(' Mastery target  : SR %.1f%% | saturation <= %.1f%%\n', ...
        100*stage.masteryThreshold, 100*stage.maxActionSaturationRate);
    fprintf('===============================================================\n');

    % Skenario validasi dibuat sekali per stage dan dipakai untuk seluruh
    % block agar perbandingan checkpoint adil.
    stageValidationScenarios = generateScenarioBankV136( ...
        config, stage.numValidationScenarios, ...
        execution.validationSeed + 1000*stageIndex, ...
        stage, true);
    stageValidationBanks{stageIndex} = stageValidationScenarios;

    for blockIndex = 1:stage.maxBlocks
        fprintf('\nStage %d | Block %d/%d | Episodes: %d\n', ...
            stageIndex, blockIndex, stage.maxBlocks, ...
            stage.episodesPerBlock);

        DDPG_V136_RUNTIME.CurrentStageIndex = stageIndex;
        DDPG_V136_RUNTIME.CurrentBlockIndex = blockIndex;
        DDPG_V136_RUNTIME.RecordingEnabled = true;

        trainOptions = createTrainingOptionsV136( ...
            stage.episodesPerBlock, stage.maxSteps, execution.mode);

        blockStart = tic;
        blockStats = train(agent, env, trainOptions);
        blockTimeSeconds = toc(blockStart);
        trainingHistory{stageIndex,blockIndex} = blockStats;
        DDPG_V136_RUNTIME.RecordingEnabled = false;

        validationResults = evaluateAgentOnScenariosV136( ...
            agent, stageValidationScenarios, config);
        validationSummary = summarizeEvaluationV136(validationResults);
        validationSuccess = validationSummary.SuccessRate(1);
        validationSaturation = validationSummary.MeanActionSaturationRate(1);

        checkpointName = sprintf( ...
            'DDPG_v13_6_Stage%02d_Block%02d_SR%05.1f_SAT%05.1f.mat', ...
            stageIndex, blockIndex, 100*validationSuccess, ...
            100*validationSaturation);
        checkpointPath = fullfile( ...
            config.output.checkpointDirectory, checkpointName);

        checkpointMetadata.stageIndex = stageIndex;
        checkpointMetadata.stageName = stage.name;
        checkpointMetadata.blockIndex = blockIndex;
        checkpointMetadata.globalEpisodeIndex = ...
            DDPG_V136_RUNTIME.GlobalEpisodeIndex;
        checkpointMetadata.validationSummary = validationSummary;
        checkpointMetadata.trainingTimeSeconds = blockTimeSeconds;
        save(checkpointPath, 'agent', 'checkpointMetadata', ...
            'validationResults', 'stage');

        checkpointFiles(end+1,1) = string(checkpointPath); %#ok<SAGROW>
        stageCheckpointFiles{stageIndex}(end+1,1) = ...
            string(checkpointPath); %#ok<SAGROW>

        stageLog = appendStageLogV136(stageLog, stage, blockIndex, ...
            DDPG_V136_RUNTIME.GlobalEpisodeIndex, blockTimeSeconds, ...
            validationSummary, checkpointName);

        fprintf('Validation: SR=%.1f%% | Collision=%.1f%% | ', ...
            100*validationSummary.SuccessRate(1), ...
            100*validationSummary.CollisionRate(1));
        fprintf(['Boundary=%.1f%% | Timeout=%.1f%% | FinalDist=%.2f m | ' ...
            'FinalSpeed=%.2f m/s | Sat=%.1f%%\n'], ...
            100*validationSummary.BoundaryRate(1), ...
            100*validationSummary.TimeoutRate(1), ...
            validationSummary.MeanFinalDistance(1), ...
            validationSummary.MeanFinalSpeed(1), ...
            100*validationSummary.MeanActionSaturationRate(1));
        fprintf('Checkpoint: %s\n', checkpointName);

        if validationSuccess >= stage.masteryThreshold && ...
                validationSaturation <= stage.maxActionSaturationRate
            stageMastered = true;
            fprintf('STAGE %d MASTERED.\n', stageIndex);
            break;
        end
    end

    % Pemilihan hanya menggunakan checkpoint pada stage yang sedang
    % dikuasai, bukan bank obstacle final yang belum pernah dipelajari.
    [stageBestAgent, stageCandidateTable, stageBestCheckpoint] = ...
        selectBestCheckpointLexicographicV136( ...
        agent, stageCheckpointFiles{stageIndex}, ...
        stageValidationScenarios, config);

    if config.curriculum.restoreBestCheckpointEachStage
        agent = stageBestAgent;
    end

    stageCandidateTables{stageIndex} = stageCandidateTable;
    stageBestLog = appendStageBestLogV136(stageBestLog, stage, ...
        stageMastered, stageBestCheckpoint, stageCandidateTable);

    fprintf('Best checkpoint Stage %d: %s\n', ...
        stageIndex, stageBestCheckpoint);
    disp(stageCandidateTable);

    stageMasteredFlags(stageIndex) = stageMastered;
    if stageMastered
        highestMasteredStage = stageIndex;
    else
        if execution.mode == "smoke"
            fprintf(['Smoke mode: Stage %d belum mastered; forced advance ' ...
                'hanya untuk memeriksa struktur.\n'], stageIndex);
        else
            warning('Stage %d belum mencapai mastery threshold %.1f%%.', ...
                stageIndex, 100*stage.masteryThreshold);
            fprintf(['Curriculum dihentikan. Agent terbaik pada stage ini ' ...
                'tetap dipulihkan dan disimpan.\n']);
            stopCurriculum = true;
        end
    end

    if stopCurriculum
        break;
    end
end

trainingTimeSeconds = toc(trainingStart);
DDPG_V136_RUNTIME.RecordingEnabled = false;

fprintf('\nTotal curriculum training time: %.2f hours\n', ...
    trainingTimeSeconds/3600);

%% ========================================================================
%  BAGIAN 12: RINGKASAN CHECKPOINT TERPILIH
%  ========================================================================

fprintf('\nSTAGE-BEST CHECKPOINT SUMMARY\n');
disp(stageBestLog);

if highestAttemptedStage > 0
    bestCheckpoint = stageBestLog.BestCheckpoint(end);
else
    bestCheckpoint = "CurrentAgent";
end
fprintf('Agent output berasal dari: %s\n', bestCheckpoint);

%% ========================================================================
%  BAGIAN 13: FINAL 10-OBSTACLE TEST (HANYA SETELAH FINAL MASTERY)
%  ========================================================================

finalTestPerformed = highestMasteredStage == config.curriculum.numStages;
final10Scenarios = struct([]);
final10Results = struct();
final10Summary = table();

if finalTestPerformed
    finalStage = stages(end);
    finalStage.target = config.mission.finalTarget;
    finalStage.allowedObstacleCounts = 10;
    finalStage.maxSteps = config.mission.defaultMaxSteps;
    final10Scenarios = generateScenarioBankV136( ...
        config, config.test.numScenariosFinal10, execution.testSeed, ...
        finalStage, false);
    final10Results = evaluateAgentOnScenariosV136( ...
        agent, final10Scenarios, config);
    final10Summary = summarizeEvaluationV136(final10Results);
    fprintf('\nFINAL TEST: 10 OBSTACLES\n');
    disp(final10Summary);
else
    fprintf(['\nFINAL 10-OBSTACLE TEST DITUNDA: stage final belum mastered.\n' ...
        'Highest mastered stage: %d dari %d.\n'], ...
        highestMasteredStage, config.curriculum.numStages);
end

%% ========================================================================
%  BAGIAN 14: STAGE-WISE DIAGNOSTIC TEST
%  ========================================================================

diagnosticScenarios = cell(highestAttemptedStage,1);
diagnosticResults = cell(highestAttemptedStage,1);
diagnosticSummary = table();

for i = 1:highestAttemptedStage
    diagnosticStage = stages(i);
    scenarios = generateScenarioBankV136( ...
        config, config.test.numScenariosPerStage, ...
        execution.testSeed + 100*i, ...
        diagnosticStage, true);
    results = evaluateAgentOnScenariosV136(agent, scenarios, config);
    summary = summarizeEvaluationV136(results);
    summary.Stage = i;
    summary.StageName = diagnosticStage.name;
    summary.Target = string(sprintf('[%.1f %.1f]', ...
        diagnosticStage.target(1), diagnosticStage.target(2)));
    summary.MaxSteps = diagnosticStage.maxSteps;
    summary.ObstacleCounts = string(mat2str( ...
        diagnosticStage.allowedObstacleCounts));
    diagnosticScenarios{i} = scenarios;
    diagnosticResults{i} = results;
    diagnosticSummary = [diagnosticSummary; summary]; %#ok<AGROW>
end

if ~isempty(diagnosticSummary)
    diagnosticSummary = movevars(diagnosticSummary, ...
        {'Stage','StageName','Target','MaxSteps','ObstacleCounts'}, ...
        'Before', 1);
end

fprintf('\nSTAGE-WISE DIAGNOSTIC SUMMARY\n');
disp(diagnosticSummary);

%% ========================================================================
%  BAGIAN 15: SAVE OUTPUT
%  ========================================================================

runtimeStats = DDPG_V136_RUNTIME.Stats;
metadata.script = mfilename;
metadata.execution = execution;
metadata.trainingTimeSeconds = trainingTimeSeconds;
metadata.bestCheckpoint = bestCheckpoint;
metadata.highestAttemptedStage = highestAttemptedStage;
metadata.highestMasteredStage = highestMasteredStage;
metadata.stageMasteredFlags = stageMasteredFlags;
metadata.finalTestPerformed = finalTestPerformed;
metadata.createdAt = datetime('now');
metadata.outcomeCodes = struct( ...
    'running',0, 'success',1, 'collision',2, ...
    'boundary',3, 'timeout',4);
metadata.actionSemantics = struct( ...
    'component1','parallel-to-goal acceleration', ...
    'component2','lateral-to-goal acceleration');
metadata.observationFrame = 'goal-relative rotation-invariant';
metadata.methodTag = 'GF';
metadata.configTag = 'V13_6_GF';
metadata.runLabel = 'DDPG_v13_6_GF_MS01';
metadata.comparatorProtocol = 'PG_vs_GF_v1_0';
metadata.gfFrozenSettings = struct( ...
    'desiredSpeedMode','constant-vmax', ...
    'warningClearanceMode','fixed-base-clearance', ...
    'trainingTargetRadius',0.50, ...
    'trainingArrivalSpeed',0.50, ...
    'trainingMaxSteps',300);

agentFile = fullfile(config.output.rootDirectory, ...
    'DDPG_Quadcopter_Agent_v13_6.mat');
trainingFile = fullfile(config.output.rootDirectory, ...
    'DDPG_Training_Stats_v13_6.mat');
testFile = fullfile(config.output.rootDirectory, ...
    'DDPG_Test_Results_v13_6.mat');

save(agentFile, 'agent', 'config', 'stages', 'metadata');
save(trainingFile, 'trainingHistory', 'runtimeStats', 'stageLog', ...
    'stageBestLog', 'stageCheckpointFiles', 'stageValidationBanks', ...
    'stageCandidateTables', 'checkpointFiles', ...
    'config', 'stages', 'metadata');
save(testFile, 'finalTestPerformed', 'final10Results', ...
    'final10Summary', 'final10Scenarios', 'diagnosticScenarios', ...
    'diagnosticResults', ...
    'diagnosticSummary', 'config', 'stages', 'metadata');

fprintf('\nOutput tersimpan di folder %s:\n', config.output.rootDirectory);
fprintf('  DDPG_Quadcopter_Agent_v13_6.mat\n');
fprintf('  DDPG_Training_Stats_v13_6.mat\n');
fprintf('  DDPG_Test_Results_v13_6.mat\n');
fprintf('  checkpoints/\n');

%% ========================================================================
%  LOCAL FUNCTIONS
%  ========================================================================

function stage = makeStageV136(index, name, allowedCounts, target, ...
        samplingMode, samplingSpec, targetRadius, arrivalSpeed, ...
        maxSteps, threshold, maxSaturation)

    stage.index = index;
    stage.name = string(name);
    stage.allowedObstacleCounts = allowedCounts;
    stage.target = double(target(:));
    stage.samplingMode = string(samplingMode);
    stage.samplingSpec = samplingSpec;
    stage.targetRadius = targetRadius;
    stage.arrivalSpeed = arrivalSpeed;
    stage.maxSteps = maxSteps;
    stage.masteryThreshold = threshold;
    stage.maxActionSaturationRate = maxSaturation;
    stage.episodesPerBlock = 0;
    stage.maxBlocks = 0;
    stage.numValidationScenarios = 0;
end

function prepareOutputDirectoryV136(rootDirectory, checkpointDirectory)
    if exist(rootDirectory, 'dir')
        timestamp = char(datetime('now','Format','yyyyMMdd_HHmmss'));
        archived = [rootDirectory '_ARCHIVE_' timestamp];
        movefile(rootDirectory, archived);
        fprintf('Output lama dipindahkan ke: %s\n', archived);
    end
    mkdir(rootDirectory);
    mkdir(checkpointDirectory);
end

function options = createTrainingOptionsV136(numEpisodes, maxSteps, mode)
    options = rlTrainingOptions;
    options.MaxEpisodes = numEpisodes;
    options.MaxStepsPerEpisode = maxSteps;
    options.ScoreAveragingWindowLength = min(50, max(5,numEpisodes));
    options.Verbose = true;
    if mode == "smoke"
        options.Plots = 'none';
    else
        options.Plots = 'none';
    end
end

function runtime = initializeRuntimeV136(config, execution, stages)
    runtime.GlobalEpisodeIndex = 0;
    runtime.CurrentStageIndex = 1;
    runtime.CurrentBlockIndex = 1;
    runtime.RecordingEnabled = false;
    runtime.Stream = RandStream('mt19937ar', ...
        'Seed', execution.environmentSeed);
    runtime.Stats = initializeStatsV136();
    runtime.Stages = stages;
end

function stats = initializeStatsV136()
    stats.episode = zeros(0,1);
    stats.stage = zeros(0,1);
    stats.block = zeros(0,1);
    stats.outcome = zeros(0,1);
    stats.steps = zeros(0,1);
    stats.maxSteps = zeros(0,1);
    stats.totalReward = zeros(0,1);
    stats.pathLength = zeros(0,1);
    stats.directDistance = zeros(0,1);
    stats.directness = zeros(0,1);
    stats.minimumClearance = zeros(0,1);
    stats.obstacleCount = zeros(0,1);
    stats.startX = zeros(0,1);
    stats.startY = zeros(0,1);
    stats.targetX = zeros(0,1);
    stats.targetY = zeros(0,1);
    stats.initialGoalBearingDeg = zeros(0,1);
    stats.finalX = zeros(0,1);
    stats.finalY = zeros(0,1);
    stats.finalDistance = zeros(0,1);
    stats.finalSpeed = zeros(0,1);
    stats.targetRadius = zeros(0,1);
    stats.arrivalSpeed = zeros(0,1);
    stats.meanActionParallel = zeros(0,1);
    stats.meanActionLateral = zeros(0,1);
    stats.meanWorldCommandX = zeros(0,1);
    stats.meanWorldCommandY = zeros(0,1);
    stats.actionSaturationRate = zeros(0,1);
end

function logTable = initializeStageLogV136()
    logTable = table( ...
        zeros(0,1), zeros(0,1), strings(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), strings(0,1), ...
        'VariableNames', {'Stage','Block','StageName','GlobalEpisode', ...
        'TrainingTimeSeconds','SuccessRate','CollisionRate', ...
        'BoundaryRate','TimeoutRate','MeanFinalDistance', ...
        'MeanFinalSpeed','MeanActionSaturationRate', ...
        'MeanTotalReward','Checkpoint'});
end

function logTable = appendStageLogV136(logTable, stage, block, ...
        globalEpisode, trainingTimeSeconds, summary, checkpoint)
    newRow = table(stage.index, block, stage.name, globalEpisode, ...
        trainingTimeSeconds, summary.SuccessRate(1), ...
        summary.CollisionRate(1), summary.BoundaryRate(1), ...
        summary.TimeoutRate(1), summary.MeanFinalDistance(1), ...
        summary.MeanFinalSpeed(1), summary.MeanActionSaturationRate(1), ...
        summary.MeanTotalReward(1), string(checkpoint), ...
        'VariableNames', logTable.Properties.VariableNames);
    logTable = [logTable; newRow];
end

function logTable = initializeStageBestLogV136()
    logTable = table( ...
        zeros(0,1), strings(0,1), false(0,1), strings(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
        'VariableNames', {'Stage','StageName','Mastered', ...
        'BestCheckpoint','SuccessRate','MeanActionSaturationRate', ...
        'MeanFinalDistance','MeanFinalSpeed','CollisionRate', ...
        'BoundaryRate','TimeoutRate','MeanSuccessfulSteps'});
end

function logTable = appendStageBestLogV136(logTable, stage, mastered, ...
        bestCheckpoint, candidateTable)
    best = candidateTable(1,:);
    newRow = table(stage.index, stage.name, logical(mastered), ...
        string(bestCheckpoint), best.successRate(1), ...
        best.meanActionSaturationRate(1), best.meanFinalDistance(1), ...
        best.meanFinalSpeed(1), best.collisionRate(1), ...
        best.boundaryRate(1), best.timeoutRate(1), ...
        best.meanSuccessfulSteps(1), ...
        'VariableNames', logTable.Properties.VariableNames);
    logTable = [logTable; newRow];
end

function agentOptions = setDDPGNoiseOptionsV136( ...
        agentOptions, agentConfig, numActions)
    noiseOptions = agentOptions.NoiseOptions;
    initialStd = agentConfig.explorationInitialStd*ones(numActions,1);
    minimumStd = agentConfig.explorationMinimumStd*ones(numActions,1);
    if isprop(noiseOptions, 'StandardDeviation')
        noiseOptions.StandardDeviation = initialStd;
        noiseOptions.StandardDeviationDecayRate = ...
            agentConfig.explorationDecayRate;
        noiseOptions.StandardDeviationMin = minimumStd;
    else
        noiseOptions.Variance = initialStd;
        noiseOptions.VarianceDecayRate = agentConfig.explorationDecayRate;
        noiseOptions.VarianceMin = minimumStd;
    end
    agentOptions.NoiseOptions = noiseOptions;
end

function [initialObservation, logged] = quadcopterResetV136(config)
    global DDPG_V136_RUNTIME;

    stage = DDPG_V136_RUNTIME.Stages( ...
        DDPG_V136_RUNTIME.CurrentStageIndex);

    activeObstacles = sampleEpisodeObstaclesV136( ...
        config.map.obstacles, stage.allowedObstacleCounts, ...
        config.curriculum.randomizeObstacleSubset, ...
        DDPG_V136_RUNTIME.Stream);

    startPosition = sampleValidStartV136( ...
        stage, activeObstacles, config, DDPG_V136_RUNTIME.Stream);

    if DDPG_V136_RUNTIME.RecordingEnabled
        DDPG_V136_RUNTIME.GlobalEpisodeIndex = ...
            DDPG_V136_RUNTIME.GlobalEpisodeIndex + 1;
    end

    state = [startPosition; zeros(2,1)];
    initialObservation = computeObservationV136( ...
        state, activeObstacles, stage.target, ...
        stage.targetRadius, stage.arrivalSpeed, config);

    logged.State = state;
    logged.StepCount = 0;
    logged.GlobalEpisodeIndex = DDPG_V136_RUNTIME.GlobalEpisodeIndex;
    logged.StageIndex = DDPG_V136_RUNTIME.CurrentStageIndex;
    logged.BlockIndex = DDPG_V136_RUNTIME.CurrentBlockIndex;
    logged.ActiveObstacles = activeObstacles;
    logged.StartPosition = startPosition;
    logged.Target = stage.target;
    logged.TargetRadius = stage.targetRadius;
    logged.ArrivalSpeed = stage.arrivalSpeed;
    logged.MaxSteps = stage.maxSteps;
    logged.PreviousWorldCommand = zeros(2,1);
    logged.TrajectoryX = startPosition(1);
    logged.TrajectoryY = startPosition(2);
    logged.MinimumClearance = minimumClearanceV136( ...
        startPosition, activeObstacles, config.quad.radius);
    logged.TotalReward = 0;
    logged.GoalActionSum = zeros(2,1);
    logged.WorldCommandSum = zeros(2,1);
    logged.ActionCount = 0;
    logged.ActionSaturationCount = 0;
    logged.ActionElementCount = 0;
end

function [nextObservation, reward, isDone, logged] = ...
        quadcopterStepV136(action, logged, config)

    goalAction = max(-1, min(1, double(action(:))));

    [nextState, reward, outcome, stepInfo] = transitionV136( ...
        logged.State, goalAction, logged.PreviousWorldCommand, ...
        logged.ActiveObstacles, logged.StepCount, logged.Target, ...
        logged.TargetRadius, logged.ArrivalSpeed, logged.MaxSteps, config);

    nextObservation = computeObservationV136( ...
        nextState, logged.ActiveObstacles, logged.Target, ...
        logged.TargetRadius, logged.ArrivalSpeed, config);

    logged.State = nextState;
    logged.StepCount = logged.StepCount + 1;
    logged.PreviousWorldCommand = stepInfo.worldCommand;
    logged.TrajectoryX(end+1,1) = nextState(1);
    logged.TrajectoryY(end+1,1) = nextState(2);
    logged.MinimumClearance = min( ...
        logged.MinimumClearance, stepInfo.minimumClearance);
    logged.TotalReward = logged.TotalReward + reward;
    logged.GoalActionSum = logged.GoalActionSum + goalAction;
    logged.WorldCommandSum = ...
        logged.WorldCommandSum + stepInfo.worldCommand;
    logged.ActionCount = logged.ActionCount + 1;
    logged.ActionSaturationCount = logged.ActionSaturationCount + ...
        sum(abs(goalAction) >= config.mastery.actionSaturationThreshold);
    logged.ActionElementCount = logged.ActionElementCount + ...
        numel(goalAction);

    isDone = outcome ~= 0;
    if isDone
        appendRuntimeStatsV136(logged, outcome);
    end
end

function [nextState, reward, outcome, info] = transitionV136( ...
        state, goalAction, previousWorldCommand, activeObstacles, ...
        stepCount, target, targetRadius, arrivalSpeed, maxSteps, config)

    position = state(1:2);
    velocity = state(3:4);
    previousDistance = norm(position-target);

    [goalDirection, lateralDirection] = goalFrameBasisV136( ...
        position, target);

    % Orthogonal transform from goal-frame action to world command.
    worldCommand = goalAction(1)*goalDirection + ...
        goalAction(2)*lateralDirection;

    % Orthogonal rotation preserves command norm. No componentwise clipping
    % is applied because it would destroy rotation invariance.
    acceleration = worldCommand*config.quad.maxAcceleration;
    nextVelocity = velocity + acceleration*config.quad.dt;
    speed = norm(nextVelocity);
    if speed > config.quad.maxVelocity
        nextVelocity = nextVelocity*(config.quad.maxVelocity/speed);
    end

    nextPosition = position + nextVelocity*config.quad.dt;
    nextDistance = norm(nextPosition-target);
    nextSpeed = norm(nextVelocity);

    reward = config.reward.step;
    reward = reward + config.reward.progressScale* ...
        (previousDistance-nextDistance);
    reward = reward - config.reward.distanceScale* ...
        (nextDistance/config.derived.maxDistance);
    reward = reward - config.reward.actionEffortScale* ...
        sum(goalAction.^2);
    reward = reward - config.reward.actionChangeScale* ...
        sum((worldCommand-previousWorldCommand).^2);
    desiredSpeed = config.quad.maxVelocity;
    overspeed = max(0, nextSpeed-desiredSpeed);
    reward = reward - config.reward.overspeedScale*overspeed^2;

    [nextGoalDirection, nextLateralDirection] = ...
        goalFrameBasisV136(nextPosition, target);
    nextRadialVelocity = dot(nextVelocity, nextGoalDirection);
    nextLateralVelocity = dot(nextVelocity, nextLateralDirection);
    reward = reward - config.reward.lateralVelocityScale* ...
        nextLateralVelocity^2;

    outcome = 0;

    boundaryDistance = minimumBoundaryDistanceV136( ...
        nextPosition, config.env);
    if boundaryDistance > 0 && ...
            boundaryDistance < config.safety.boundaryWarningDistance
        ratio = 1-boundaryDistance/ ...
            config.safety.boundaryWarningDistance;
        reward = reward - config.reward.boundaryWarningScale*ratio^2;
    end

    outside = nextPosition(1) < config.env.xMin || ...
              nextPosition(1) > config.env.xMax || ...
              nextPosition(2) < config.env.yMin || ...
              nextPosition(2) > config.env.yMax;

    if outside
        reward = reward + config.reward.boundary;
        outcome = 3;
        nextPosition(1) = min(config.env.xMax, ...
            max(config.env.xMin, nextPosition(1)));
        nextPosition(2) = min(config.env.yMax, ...
            max(config.env.yMin, nextPosition(2)));
    end

    [clearance, nearestObstacleVector] = nearestObstacleV136( ...
        nextPosition, activeObstacles, config.quad.radius);

    if outcome == 0 && clearance <= 0
        reward = reward + config.reward.collision;
        outcome = 2;
    elseif outcome == 0 && isfinite(clearance)
        if norm(nearestObstacleVector) > 0
            obstacleDirection = nearestObstacleVector / ...
                norm(nearestObstacleVector);
            closingSpeed = max(0, dot(nextVelocity, obstacleDirection));
        else
            closingSpeed = 0;
        end
        warningClearance = config.safety.baseClearance;

        if clearance < warningClearance
            ratio = 1-max(clearance,0)/warningClearance;
            reward = reward - config.reward.proximityScale*ratio^2;
        end
    end

    goalReached = nextDistance <= targetRadius && ...
        nextSpeed <= arrivalSpeed;

    if outcome == 0 && goalReached
        reward = reward + config.reward.goal;
        outcome = 1;
    end

    nextStepCount = stepCount + 1;
    if outcome == 0 && nextStepCount >= maxSteps
        reward = reward + config.reward.timeout;
        outcome = 4;
    end

    nextState = [nextPosition; nextVelocity];

    info.minimumClearance = clearance;
    info.desiredSpeed = desiredSpeed;
    info.finalSpeed = nextSpeed;
    info.radialVelocity = nextRadialVelocity;
    info.lateralVelocity = nextLateralVelocity;
    info.worldCommand = worldCommand;
end

function observation = computeObservationV136( ...
        state, activeObstacles, target, targetRadius, ...
        arrivalSpeed, config)

    position = state(1:2);
    velocity = state(3:4);

    relativeTarget = target-position;
    targetDistance = norm(relativeTarget);
    [goalDirection, lateralDirection] = ...
        goalFrameBasisV136(position, target);

    radialVelocity = dot(velocity, goalDirection);
    lateralVelocity = dot(velocity, lateralDirection);
    desiredSpeed = config.quad.maxVelocity;

    [clearance, nearestVector] = nearestObstacleV136( ...
        position, activeObstacles, config.quad.radius);

    if norm(nearestVector) > 0
        obstacleParallel = dot(nearestVector, goalDirection);
        obstacleLateral = dot(nearestVector, lateralDirection);
        relativeObstacleAngle = atan2( ...
            obstacleLateral, obstacleParallel);
        obstacleCos = cos(relativeObstacleAngle);
        obstacleSin = sin(relativeObstacleAngle);
        obstacleDirection = nearestVector/norm(nearestVector);
        obstacleClosingSpeed = max(0, dot(velocity, obstacleDirection));
    else
        obstacleCos = 0;
        obstacleSin = 0;
        obstacleClosingSpeed = 0;
    end

    if isfinite(clearance)
        normalizedClearance = clearance/ ...
            config.safety.observationClearanceScale;
    else
        normalizedClearance = 1;
    end

    forwardBoundary = rayDistanceToBoundaryV136( ...
        position, goalDirection, config.env);
    backwardBoundary = rayDistanceToBoundaryV136( ...
        position, -goalDirection, config.env);
    leftBoundary = rayDistanceToBoundaryV136( ...
        position, lateralDirection, config.env);
    rightBoundary = rayDistanceToBoundaryV136( ...
        position, -lateralDirection, config.env);

    observation = [
        targetDistance/config.derived.maxDistance;
        radialVelocity/config.quad.maxVelocity;
        lateralVelocity/config.quad.maxVelocity;
        normalizedClearance;
        obstacleCos;
        obstacleSin;
        obstacleClosingSpeed/config.quad.maxVelocity;
        forwardBoundary/config.derived.maxDistance;
        backwardBoundary/config.derived.maxDistance;
        leftBoundary/config.derived.maxDistance;
        rightBoundary/config.derived.maxDistance;
        targetRadius/2.0;
        arrivalSpeed/config.quad.maxVelocity;
        desiredSpeed/config.quad.maxVelocity
    ];

    observation = max(-1, min(1, observation));
end

function appendRuntimeStatsV136(logged, outcome)
    global DDPG_V136_RUNTIME;

    if ~DDPG_V136_RUNTIME.RecordingEnabled
        return;
    end

    pathLength = pathLengthV136(logged.TrajectoryX, logged.TrajectoryY);
    directDistance = norm(logged.Target-logged.StartPosition);

    if outcome == 1 && pathLength > 0
        directness = min(1, directDistance/pathLength);
    else
        directness = NaN;
    end

    if logged.ActionCount > 0
        meanGoalAction = logged.GoalActionSum/logged.ActionCount;
        meanWorldCommand = logged.WorldCommandSum/logged.ActionCount;
    else
        meanGoalAction = zeros(2,1);
        meanWorldCommand = zeros(2,1);
    end

    if logged.ActionElementCount > 0
        saturationRate = ...
            logged.ActionSaturationCount/logged.ActionElementCount;
    else
        saturationRate = 0;
    end

    s = DDPG_V136_RUNTIME.Stats;
    s.episode(end+1,1) = logged.GlobalEpisodeIndex;
    s.stage(end+1,1) = logged.StageIndex;
    s.block(end+1,1) = logged.BlockIndex;
    s.outcome(end+1,1) = outcome;
    s.steps(end+1,1) = logged.StepCount;
    s.maxSteps(end+1,1) = logged.MaxSteps;
    s.totalReward(end+1,1) = logged.TotalReward;
    s.pathLength(end+1,1) = pathLength;
    s.directDistance(end+1,1) = directDistance;
    s.directness(end+1,1) = directness;
    s.minimumClearance(end+1,1) = logged.MinimumClearance;
    s.obstacleCount(end+1,1) = size(logged.ActiveObstacles,1);
    s.startX(end+1,1) = logged.StartPosition(1);
    s.startY(end+1,1) = logged.StartPosition(2);
    s.targetX(end+1,1) = logged.Target(1);
    s.targetY(end+1,1) = logged.Target(2);
    initialTargetVector = logged.Target-logged.StartPosition;
    s.initialGoalBearingDeg(end+1,1) = atan2d( ...
        initialTargetVector(2), initialTargetVector(1));
    s.finalX(end+1,1) = logged.State(1);
    s.finalY(end+1,1) = logged.State(2);
    s.finalDistance(end+1,1) = norm( ...
        logged.State(1:2)-logged.Target);
    s.finalSpeed(end+1,1) = norm(logged.State(3:4));
    s.targetRadius(end+1,1) = logged.TargetRadius;
    s.arrivalSpeed(end+1,1) = logged.ArrivalSpeed;
    s.meanActionParallel(end+1,1) = meanGoalAction(1);
    s.meanActionLateral(end+1,1) = meanGoalAction(2);
    s.meanWorldCommandX(end+1,1) = meanWorldCommand(1);
    s.meanWorldCommandY(end+1,1) = meanWorldCommand(2);
    s.actionSaturationRate(end+1,1) = saturationRate;

    DDPG_V136_RUNTIME.Stats = s;
end

function activeObstacles = sampleEpisodeObstaclesV136( ...
        allObstacles, allowedCounts, randomizeSubset, stream)

    allowedCounts = allowedCounts(:)';
    countIndex = randi(stream, numel(allowedCounts));
    obstacleCount = allowedCounts(countIndex);
    obstacleCount = min(obstacleCount, size(allObstacles,1));

    if obstacleCount == size(allObstacles,1)
        activeObstacles = allObstacles;
    elseif randomizeSubset
        randomValues = rand(stream, size(allObstacles,1), 1);
        [~, order] = sort(randomValues);
        activeObstacles = allObstacles(order(1:obstacleCount),:);
    else
        activeObstacles = allObstacles(1:obstacleCount,:);
    end
end

function position = sampleValidStartV136(stage, obstacles, config, stream)
    maxAttempts = 5000;

    for attempt = 1:maxAttempts
        if stage.samplingMode == "polar"
            dMin = stage.samplingSpec(1);
            dMax = stage.samplingSpec(2);
            aMin = stage.samplingSpec(3);
            aMax = stage.samplingSpec(4);

            distance = dMin + rand(stream)*(dMax-dMin);
            angle = deg2rad(aMin + rand(stream)*(aMax-aMin));

            candidate = stage.target - ...
                distance*[cos(angle); sin(angle)];

        elseif stage.samplingMode == "region"
            spec = stage.samplingSpec;
            x = spec(1) + rand(stream)*(spec(2)-spec(1));
            y = spec(3) + rand(stream)*(spec(4)-spec(3));
            candidate = [x; y];

        else
            error('samplingMode tidak dikenal: %s', stage.samplingMode);
        end

        clearance = minimumClearanceV136( ...
            candidate, obstacles, config.quad.radius);
        targetDistance = norm(candidate-stage.target);
        boundaryDistance = minimumBoundaryDistanceV136( ...
            candidate, config.env);

        if clearance >= config.safety.startClearanceMargin && ...
                boundaryDistance >= config.safety.startBoundaryMargin && ...
                targetDistance > 1.5*stage.targetRadius
            position = candidate;
            return;
        end
    end

    error(['Gagal menghasilkan posisi awal valid setelah %d percobaan. ' ...
        'Periksa target, samplingSpec, dan obstacle stage.'], maxAttempts);
end

function scenarios = generateScenarioBankV136( ...
        config, numberOfScenarios, seed, stage, randomizeSubset)

    stream = RandStream('mt19937ar', 'Seed', seed);

    template = struct( ...
        'id',0, ...
        'start',[0;0], ...
        'target',stage.target, ...
        'obstacles',zeros(0,3), ...
        'obstacleCount',0, ...
        'targetRadius',stage.targetRadius, ...
        'arrivalSpeed',stage.arrivalSpeed, ...
        'maxSteps',stage.maxSteps);

    scenarios = repmat(template, numberOfScenarios, 1);

    for i = 1:numberOfScenarios
        obstacles = sampleEpisodeObstaclesV136( ...
            config.map.obstacles, stage.allowedObstacleCounts, ...
            randomizeSubset, stream);

        start = sampleValidStartV136( ...
            stage, obstacles, config, stream);

        scenarios(i).id = i;
        scenarios(i).start = start;
        scenarios(i).target = stage.target;
        scenarios(i).obstacles = obstacles;
        scenarios(i).obstacleCount = size(obstacles,1);
        scenarios(i).targetRadius = stage.targetRadius;
        scenarios(i).arrivalSpeed = stage.arrivalSpeed;
        scenarios(i).maxSteps = stage.maxSteps;
    end
end

function results = evaluateAgentOnScenariosV136(agent, scenarios, config)
    n = numel(scenarios);

    results.scenarioId = zeros(n,1);
    results.obstacleCount = zeros(n,1);
    results.startX = zeros(n,1);
    results.startY = zeros(n,1);
    results.targetX = zeros(n,1);
    results.targetY = zeros(n,1);
    results.initialGoalBearingDeg = zeros(n,1);
    results.finalX = zeros(n,1);
    results.finalY = zeros(n,1);
    results.targetRadius = zeros(n,1);
    results.arrivalSpeed = zeros(n,1);
    results.maxSteps = zeros(n,1);
    results.outcome = zeros(n,1);
    results.success = false(n,1);
    results.collision = false(n,1);
    results.boundary = false(n,1);
    results.timeout = false(n,1);
    results.totalReward = zeros(n,1);
    results.steps = zeros(n,1);
    results.pathLength = zeros(n,1);
    results.directDistance = zeros(n,1);
    results.directness = NaN(n,1);
    results.minimumClearance = zeros(n,1);
    results.finalDistance = zeros(n,1);
    results.finalSpeed = zeros(n,1);
    results.controlEffort = zeros(n,1);
    results.actionVariation = zeros(n,1);
    results.meanActionParallel = zeros(n,1);
    results.meanActionLateral = zeros(n,1);
    results.meanWorldCommandX = zeros(n,1);
    results.meanWorldCommandY = zeros(n,1);
    results.actionSaturationRate = zeros(n,1);
    results.trajectories = cell(n,1);

    for i = 1:n
        scenario = scenarios(i);
        state = [scenario.start; zeros(2,1)];
        previousWorldCommand = zeros(2,1);

        trajectoryX = state(1);
        trajectoryY = state(2);
        totalReward = 0;

        minimumClearance = minimumClearanceV136( ...
            state(1:2), scenario.obstacles, config.quad.radius);

        controlEffort = 0;
        actionVariation = 0;
        goalActionSum = zeros(2,1);
        worldCommandSum = zeros(2,1);
        actionCount = 0;
        saturationCount = 0;
        actionElementCount = 0;
        outcome = 0;

        for stepCount = 0:scenario.maxSteps-1
            observation = computeObservationV136( ...
                state, scenario.obstacles, scenario.target, ...
                scenario.targetRadius, scenario.arrivalSpeed, config);

            goalAction = getAction(agent, observation);
            if iscell(goalAction)
                goalAction = goalAction{1};
            end
            goalAction = max(-1, min(1, double(goalAction(:))));

            [state, reward, outcome, info] = transitionV136( ...
                state, goalAction, previousWorldCommand, ...
                scenario.obstacles, stepCount, scenario.target, ...
                scenario.targetRadius, scenario.arrivalSpeed, ...
                scenario.maxSteps, config);

            totalReward = totalReward + reward;
            controlEffort = controlEffort + ...
                sum(goalAction.^2)*config.quad.dt;
            actionVariation = actionVariation + ...
                sum((info.worldCommand-previousWorldCommand).^2);

            goalActionSum = goalActionSum + goalAction;
            worldCommandSum = worldCommandSum + info.worldCommand;
            actionCount = actionCount + 1;
            saturationCount = saturationCount + ...
                sum(abs(goalAction) >= ...
                config.mastery.actionSaturationThreshold);
            actionElementCount = actionElementCount + numel(goalAction);

            previousWorldCommand = info.worldCommand;
            minimumClearance = min( ...
                minimumClearance, info.minimumClearance);

            trajectoryX(end+1,1) = state(1); %#ok<AGROW>
            trajectoryY(end+1,1) = state(2); %#ok<AGROW>

            if outcome ~= 0
                break;
            end
        end

        pathLength = pathLengthV136(trajectoryX, trajectoryY);
        directDistance = norm(scenario.target-scenario.start);

        if outcome == 1 && pathLength > 0
            directness = min(1, directDistance/pathLength);
        else
            directness = NaN;
        end

        if actionCount > 0
            meanGoalAction = goalActionSum/actionCount;
            meanWorldCommand = worldCommandSum/actionCount;
        else
            meanGoalAction = zeros(2,1);
            meanWorldCommand = zeros(2,1);
        end

        if actionElementCount > 0
            saturationRate = saturationCount/actionElementCount;
        else
            saturationRate = 0;
        end

        results.scenarioId(i) = scenario.id;
        results.obstacleCount(i) = scenario.obstacleCount;
        results.startX(i) = scenario.start(1);
        results.startY(i) = scenario.start(2);
        results.targetX(i) = scenario.target(1);
        results.targetY(i) = scenario.target(2);
        initialTargetVector = scenario.target-scenario.start;
        results.initialGoalBearingDeg(i) = atan2d( ...
            initialTargetVector(2), initialTargetVector(1));
        results.finalX(i) = state(1);
        results.finalY(i) = state(2);
        results.targetRadius(i) = scenario.targetRadius;
        results.arrivalSpeed(i) = scenario.arrivalSpeed;
        results.maxSteps(i) = scenario.maxSteps;
        results.outcome(i) = outcome;
        results.success(i) = outcome == 1;
        results.collision(i) = outcome == 2;
        results.boundary(i) = outcome == 3;
        results.timeout(i) = outcome == 4;
        results.totalReward(i) = totalReward;
        results.steps(i) = numel(trajectoryX)-1;
        results.pathLength(i) = pathLength;
        results.directDistance(i) = directDistance;
        results.directness(i) = directness;
        results.minimumClearance(i) = minimumClearance;
        results.finalDistance(i) = norm(state(1:2)-scenario.target);
        results.finalSpeed(i) = norm(state(3:4));
        results.controlEffort(i) = controlEffort;
        results.actionVariation(i) = actionVariation;
        results.meanActionParallel(i) = meanGoalAction(1);
        results.meanActionLateral(i) = meanGoalAction(2);
        results.meanWorldCommandX(i) = meanWorldCommand(1);
        results.meanWorldCommandY(i) = meanWorldCommand(2);
        results.actionSaturationRate(i) = saturationRate;
        results.trajectories{i} = struct( ...
            'x',trajectoryX, 'y',trajectoryY);
    end
end

function summary = summarizeEvaluationV136(results)
    success = results.success;

    successfulPath = NaN;
    successfulDirectness = NaN;
    successfulSteps = NaN;
    successfulEffort = NaN;
    successfulVariation = NaN;
    successfulFinalSpeed = NaN;

    if any(success)
        successfulPath = mean(results.pathLength(success));
        successfulDirectness = ...
            mean(results.directness(success), 'omitnan');
        successfulSteps = mean(results.steps(success));
        successfulEffort = mean(results.controlEffort(success));
        successfulVariation = ...
            mean(results.actionVariation(success));
        successfulFinalSpeed = mean(results.finalSpeed(success));
    end

    summary = table( ...
        numel(success), ...
        mean(results.success), ...
        mean(results.collision), ...
        mean(results.boundary), ...
        mean(results.timeout), ...
        mean(results.totalReward), ...
        mean(results.finalDistance), ...
        mean(results.finalSpeed), ...
        mean(results.actionSaturationRate), ...
        mean(results.meanActionParallel), ...
        mean(results.meanActionLateral), ...
        mean(results.meanWorldCommandX), ...
        mean(results.meanWorldCommandY), ...
        mean(results.finalX), ...
        mean(results.finalY), ...
        mean(results.minimumClearance), ...
        successfulPath, ...
        successfulDirectness, ...
        successfulSteps, ...
        successfulEffort, ...
        successfulVariation, ...
        successfulFinalSpeed, ...
        'VariableNames', { ...
        'NumScenarios','SuccessRate','CollisionRate', ...
        'BoundaryRate','TimeoutRate','MeanTotalReward', ...
        'MeanFinalDistance','MeanFinalSpeed', ...
        'MeanActionSaturationRate','MeanActionParallel', ...
        'MeanActionLateral','MeanWorldCommandX', ...
        'MeanWorldCommandY','MeanFinalX','MeanFinalY', ...
        'MeanMinimumClearance','MeanSuccessfulPathLength', ...
        'MeanSuccessfulDirectness','MeanSuccessfulSteps', ...
        'MeanSuccessfulControlEffort', ...
        'MeanSuccessfulActionVariation', ...
        'MeanSuccessfulFinalSpeed'});
end

function [bestAgent, candidateTable, bestCheckpoint] = ...
        selectBestCheckpointLexicographicV136( ...
        currentAgent, checkpointFiles, scenarios, config)

    if isempty(checkpointFiles)
        candidateNames = "CurrentAgent";
        candidateAgents = {currentAgent};
    else
        candidateNames = checkpointFiles(:);
        candidateAgents = cell(numel(candidateNames),1);
        validCandidate = true(numel(candidateNames),1);

        for i = 1:numel(candidateNames)
            loaded = load(char(candidateNames(i)), 'agent');
            if isfield(loaded, 'agent')
                candidateAgents{i} = loaded.agent;
            else
                validCandidate(i) = false;
            end
        end

        candidateNames = candidateNames(validCandidate);
        candidateAgents = candidateAgents(validCandidate);

        if isempty(candidateNames)
            candidateNames = "CurrentAgent";
            candidateAgents = {currentAgent};
        end
    end

    n = numel(candidateNames);

    names = strings(n,1);
    successRate = zeros(n,1);
    meanActionSaturationRate = zeros(n,1);
    meanFinalDistance = zeros(n,1);
    meanFinalSpeed = zeros(n,1);
    collisionRate = zeros(n,1);
    boundaryRate = zeros(n,1);
    timeoutRate = zeros(n,1);
    meanSuccessfulSteps = inf(n,1);
    meanTotalReward = zeros(n,1);

    for i = 1:n
        evaluation = evaluateAgentOnScenariosV136( ...
            candidateAgents{i}, scenarios, config);

        names(i) = candidateNames(i);
        successRate(i) = mean(evaluation.success);
        meanActionSaturationRate(i) = ...
            mean(evaluation.actionSaturationRate);
        meanFinalDistance(i) = mean(evaluation.finalDistance);
        meanFinalSpeed(i) = mean(evaluation.finalSpeed);
        collisionRate(i) = mean(evaluation.collision);
        boundaryRate(i) = mean(evaluation.boundary);
        timeoutRate(i) = mean(evaluation.timeout);
        meanTotalReward(i) = mean(evaluation.totalReward);

        if any(evaluation.success)
            meanSuccessfulSteps(i) = ...
                mean(evaluation.steps(evaluation.success));
        end
    end

    candidateTable = table( ...
        names, successRate, meanActionSaturationRate, ...
        meanFinalDistance, meanFinalSpeed, collisionRate, ...
        boundaryRate, timeoutRate, meanSuccessfulSteps, ...
        meanTotalReward);

    candidateTable = sortrows(candidateTable, ...
        {'successRate','meanActionSaturationRate', ...
        'meanFinalDistance','meanFinalSpeed','collisionRate', ...
        'boundaryRate','timeoutRate','meanSuccessfulSteps', ...
        'meanTotalReward'}, ...
        {'descend','ascend','ascend','ascend','ascend', ...
        'ascend','ascend','ascend','descend'});

    bestCheckpoint = candidateTable.names(1);
    bestIndex = find(candidateNames == bestCheckpoint, 1, 'first');
    bestAgent = candidateAgents{bestIndex};
end

function [goalDirection, lateralDirection] = ...
        goalFrameBasisV136(position, target)

    relativeTarget = target-position;
    distance = norm(relativeTarget);

    if distance > 1e-9
        goalDirection = relativeTarget/distance;
    else
        goalDirection = [1;0];
    end

    lateralDirection = [-goalDirection(2); goalDirection(1)];
end

function distance = rayDistanceToBoundaryV136(position, direction, env)
    direction = double(direction(:));
    candidates = inf(4,1);

    tolerance = 1e-12;

    if direction(1) > tolerance
        candidates(1) = (env.xMax-position(1))/direction(1);
    elseif direction(1) < -tolerance
        candidates(2) = (env.xMin-position(1))/direction(1);
    end

    if direction(2) > tolerance
        candidates(3) = (env.yMax-position(2))/direction(2);
    elseif direction(2) < -tolerance
        candidates(4) = (env.yMin-position(2))/direction(2);
    end

    candidates = candidates(candidates >= 0 & isfinite(candidates));
    if isempty(candidates)
        distance = 0;
    else
        distance = min(candidates);
    end
end

function distance = minimumBoundaryDistanceV136(position, env)
    distance = min([position(1)-env.xMin; env.xMax-position(1); ...
                    position(2)-env.yMin; env.yMax-position(2)]);
end

function [clearance, nearestVector] = nearestObstacleV136( ...
        position, obstacles, quadRadius)
    if isempty(obstacles)
        clearance = inf;
        nearestVector = zeros(2,1);
        return;
    end

    clearance = inf;
    nearestVector = zeros(2,1);
    for i = 1:size(obstacles,1)
        center = obstacles(i,1:2)';
        radius = obstacles(i,3);
        candidate = norm(position-center)-radius-quadRadius;
        if candidate < clearance
            clearance = candidate;
            nearestVector = center-position;
        end
    end
end

function clearance = minimumClearanceV136(position, obstacles, quadRadius)
    [clearance, ~] = nearestObstacleV136(position, obstacles, quadRadius);
end

function value = pathLengthV136(x, y)
    if numel(x) < 2
        value = 0;
    else
        value = sum(hypot(diff(x), diff(y)));
    end
end
