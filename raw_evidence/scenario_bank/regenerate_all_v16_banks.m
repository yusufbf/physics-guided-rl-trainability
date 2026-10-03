root = fileparts(fileparts(mfilename('fullpath')));
M = readtable(fullfile(root,'raw_mat_manifest.csv'), 'TextType','string');
outDir = fullfile(root,'scenario_bank');
fid = fopen(fullfile(outDir,'independent_regeneration.csv'),'w');
assert(fid>0);
fprintf(fid,'kind,cohort,run,bank_count,matching_scenarios,total_scenarios,exact_match\n');
failures = 0;
for i=1:height(M)
    file = fullfile(root, char(M.relative_path(i)));
    if M.kind(i)=="final_test"
        S = load(file,'config','metadata','stages','final10Scenarios');
        stage = S.stages(end);
        stage.target = S.config.mission.finalTarget;
        stage.allowedObstacleCounts = 10;
        stage.maxSteps = S.config.mission.defaultMaxSteps;
        regen = regenerate_scenario_bank_v136(S.config, ...
            S.config.test.numScenariosFinal10, S.metadata.execution.testSeed,stage,false);
        original = S.final10Scenarios;
        matched = sum(arrayfun(@(k) isequaln(regen(k),original(k)),1:numel(original)));
        exact = isequaln(regen,original);
        fprintf(fid,'final_test,%s,%s,1,%d,%d,%d\n', ...
            M.cohort(i),M.run(i),matched,numel(original),exact);
    else
        S = load(file,'config','metadata','stages','stageValidationBanks');
        matched = 0; total = 0; bankCount = 0; exact = true;
        for j=1:numel(S.stageValidationBanks)
            original = S.stageValidationBanks{j};
            if isempty(original); continue; end
            bankCount = bankCount+1;
            stage = S.stages(j);
            regen = regenerate_scenario_bank_v136(S.config, ...
                stage.numValidationScenarios, ...
                S.metadata.execution.validationSeed + 1000*j,stage,true);
            matched = matched + sum(arrayfun(@(k) isequaln(regen(k),original(k)),1:numel(original)));
            total = total + numel(original);
            exact = exact && isequaln(regen,original);
        end
        fprintf(fid,'validation,%s,%s,%d,%d,%d,%d\n', ...
            M.cohort(i),M.run(i),bankCount,matched,total,exact);
    end
    if ~exact; failures=failures+1; end
end
fclose(fid);
fprintf('Independent bank regeneration: %d checked, %d nonmatching.\n',height(M),failures);
