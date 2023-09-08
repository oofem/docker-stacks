clear all
format long;

fileName = 'Samal_out_m2_';

fileNameStep = [fileName, num2str(1)];
handle = str2func(fileNameStep);
[mesh area data specials ReactionForces IntegrationPointFields] = handle();

NodeOfInterest = 9; % node ID with prescribed displacement

position_reaction = find(ReactionForces.DofManNumbers == NodeOfInterest);

step_from = 1;
step_to = 10;
step_step = 1;

count = 0;
for i = step_from:step_step:step_to
    count = count+1;
    step(count) = i;
    fileNameStep = [fileName, num2str(i)];
    handle = str2func(fileNameStep);
    [mesh area data specials ReactionForces IntegrationPointFields] = handle();
    
    L(count) = ReactionForces.ReactionForces{position_reaction}(2);
    D(count) = 1.e3 * data.a{1,2}(NodeOfInterest);
end

figure(1)
plot(D,L,'-ob','LineWidth',2)
axis([0 0.08 0 0.8]) 
xlabel('Displacement [mm]')
ylabel('Force [MN]')




















