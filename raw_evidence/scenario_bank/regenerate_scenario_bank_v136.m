function scenarios = regenerate_scenario_bank_v136(config, numberOfScenarios, seed, stage, randomizeSubset)
% Independent wrapper of the archived V13.6 bank-generation rules.
stream = RandStream('mt19937ar', 'Seed', seed);
template = struct('id',0,'start',[0;0],'target',stage.target, ...
    'obstacles',zeros(0,3),'obstacleCount',0, ...
    'targetRadius',stage.targetRadius,'arrivalSpeed',stage.arrivalSpeed, ...
    'maxSteps',stage.maxSteps);
scenarios = repmat(template, numberOfScenarios, 1);
for i = 1:numberOfScenarios
    obstacles = sampleEpisodeObstaclesV136(config.map.obstacles, ...
        stage.allowedObstacleCounts, randomizeSubset, stream);
    start = sampleValidStartV136(stage, obstacles, config, stream);
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

function activeObstacles = sampleEpisodeObstaclesV136(allObstacles, allowedCounts, randomizeSubset, stream)
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
        dMin = stage.samplingSpec(1); dMax = stage.samplingSpec(2);
        aMin = stage.samplingSpec(3); aMax = stage.samplingSpec(4);
        distance = dMin + rand(stream)*(dMax-dMin);
        angle = deg2rad(aMin + rand(stream)*(aMax-aMin));
        candidate = stage.target - distance*[cos(angle); sin(angle)];
    elseif stage.samplingMode == "region"
        spec = stage.samplingSpec;
        x = spec(1) + rand(stream)*(spec(2)-spec(1));
        y = spec(3) + rand(stream)*(spec(4)-spec(3));
        candidate = [x; y];
    else
        error('Unknown samplingMode: %s', stage.samplingMode);
    end
    clearance = minimumClearanceV136(candidate, obstacles, config.quad.radius);
    targetDistance = norm(candidate-stage.target);
    boundaryDistance = minimumBoundaryDistanceV136(candidate, config.env);
    if clearance >= config.safety.startClearanceMargin && ...
            boundaryDistance >= config.safety.startBoundaryMargin && ...
            targetDistance > 1.5*stage.targetRadius
        position = candidate;
        return;
    end
end
error('Unable to generate a valid start after %d attempts', maxAttempts);
end

function distance = minimumBoundaryDistanceV136(position, env)
distance = min([position(1)-env.xMin; env.xMax-position(1); ...
                position(2)-env.yMin; env.yMax-position(2)]);
end

function clearance = minimumClearanceV136(position, obstacles, quadRadius)
if isempty(obstacles)
    clearance = inf;
    return;
end
clearance = inf;
for i = 1:size(obstacles,1)
    center = obstacles(i,1:2)';
    radius = obstacles(i,3);
    candidate = norm(position-center)-radius-quadRadius;
    if candidate < clearance
        clearance = candidate;
    end
end
end
