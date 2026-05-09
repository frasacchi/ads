function [fe,Etas] = shell2fe(obj,baffOpts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
end
%SHELL2FE baff shell to fe component
%   Detailed explanation goes here
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

%check stations in correct order
if ~issorted([obj.Stations.Eta])
    error('shell stations must be in assending order with respect to Eta')
end

% get dicretised Eta positions
nodes = obj.Stations.Nodes;

% generate nodes
for i = 1:length(nodes)
    fe.Points(i) = ads.fe.Point(nodes(i,:),InputCoordSys=CS);
    % fe.Forces(i) = ads.fe.Force([0;0;0],fe.Points(i));
end

%generate material -- TODO - add MAT3 material definition
fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1)); 

% generate shell elements -- TODO - fix thickness definition!
shells = obj.Stations.Shell;
for i = 1:length(shells)
    fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),fe.Materials(end),shells(i).Thickness);
end

% Etas = obj.Stations.Eta;
% nodesX= [fe.Points.X];

Etas = obj.Stations.SecondaryEta;
Rnodes = obj.Stations.SecondaryNodes;
idxCR = any(~ismember(Rnodes, obj.Stations.ConstrainedNodes), 2);
idxER = ~ismember(Etas,obj.Stations.ConstrainedEta);
Rnodes=Rnodes(idxCR,:);
REtas = Etas(idxER);
N = size(Rnodes,1)/length(REtas);
nodesi = obj.GetPos(REtas);

% generate attachement nodes
for i = 1:length(REtas)
    fe.Points(end+1) = ads.fe.Point(nodesi(:,i),InputCoordSys=CS,isAttachment=true); % TODO Check isAttachment?
    fe.Points(end).Tag = "AttachmentNode";
    % idx = find(abs(nodesX(1,:) - nodesi(1,i)) < 1e-8);
    flat = Rnodes(1+(i-1)*N:i*N,:);
    idx = unique(flat(:)');

    REFC=123456;
    Wti = 1.0/numel(idx);
    Ci = 123456;
    fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end),REFC,Wti,Ci,fe.Points(idx));
end

%constraints - TODO
if ~isempty(obj.Stations.ConstrainedNodes)
    for j = 1:length(obj.Stations.ConstrainedEta)
    nodeCon = obj.GetPos(obj.Stations.ConstrainedEta(j));
    fe.Points(end+1) = ads.fe.Point(nodeCon,InputCoordSys=CS,isAttachment=true);
    fe.Points(end).Tag = "AttachmentNode";
    for i=1:length(obj.Stations.ConstrainedNodes(:,j))
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(end),fe.Points(obj.Stations.ConstrainedNodes(i,j)));
    end
    end
    Etas = sort([REtas,obj.Stations.ConstrainedEta]);
end

end
