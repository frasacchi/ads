% function [fe,Etas] = shell2fe(obj,baffOpts,opts)
% arguments
%     obj
%     baffOpts = ads.baff.BaffOpts();
%     opts.PointName string = ""
% end
% %SHELL2FE baff shell to fe component
% %   Detailed explanation goes here
% fe = ads.fe.Component();
% fe.Name = obj.Name;
% fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
% CS = fe.CoordSys(1);
% 
% %check stations in correct order
% if ~issorted([obj.Stations.Eta])
%     error('shell stations must be in assending order with respect to Eta')
% end
% 
% % get dicretised Eta positions
% nodes = obj.Stations.Nodes;
% 
% % generate nodes
% for i = 1:length(nodes)
%     fe.Points(i) = ads.fe.Point(nodes(i,:),InputCoordSys=CS);
%     % fe.Forces(i) = ads.fe.Force([0;0;0],fe.Points(i));
% end
% 
% %generate material -- TODO - add MAT3 material definition
% fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1)); 
% 
% % generate shell elements -- TODO - fix thickness definition!
% shells = obj.Stations.Shell;
% for i = 1:length(shells)
%     fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),fe.Materials(end),shells(i).Thickness);
% end
% 
% % Etas = obj.Stations.Eta;
% % nodesX= [fe.Points.X];
% 
% % Etas = obj.Stations.SecondaryEta;
% % Rnodes = obj.Stations.SecondaryNodes;
% % idxCR = any(~ismember(Rnodes, obj.Stations.ConstrainedNodes), 2);
% % idxER = ~ismember(Etas,obj.Stations.ConstrainedEta);
% % Rnodes=Rnodes(idxCR,:);
% % REtas = Etas(idxER);
% % N = size(Rnodes,1)/length(REtas);
% % nodesi = obj.GetPos(REtas);
% % 
% % % generate attachement nodes
% % for i = 1:length(REtas)
% %     fe.Points(end+1) = ads.fe.Point(nodesi(:,i),InputCoordSys=CS,isAttachment=true); % TODO Check isAttachment?
% %     fe.Points(end).Note = "AttachmentNode";
% %     if strlength(opts.PointName) > 0
% %         fe.Points(end).Name = opts.PointName + "_N" + i;
% %     end
% %     % idx = find(abs(nodesX(1,:) - nodesi(1,i)) < 1e-8);
% %     flat = Rnodes(1+(i-1)*N:i*N,:);
% %     idx = unique(flat(:)');
% % 
% %     REFC=123456;
% %     Wti = 1.0/numel(idx);
% %     Ci = 123456;
% %     fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end),REFC,Wti,Ci,fe.Points(idx));
% % end
% % 
% % %constraints - TODO
% % if ~isempty(obj.Stations.ConstrainedNodes)
% %     for j = 1:length(obj.Stations.ConstrainedEta)
% %     nodeCon = obj.GetPos(obj.Stations.ConstrainedEta(j));
% %     fe.Points(end+1) = ads.fe.Point(nodeCon,InputCoordSys=CS,isAttachment=true);
% %     fe.Points(end).Note = "AttachmentNode";
% %     if strlength(opts.PointName) > 0
% %         fe.Points(end).Name = opts.PointName + "_C" + j;
% %     end
% %     for i=1:length(obj.Stations.ConstrainedNodes(:,j))
% %         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(end),fe.Points(obj.Stations.ConstrainedNodes(i,j)));
% %     end
% %     end
% %     Etas = sort([REtas,obj.Stations.ConstrainedEta]);
% % end
% 
% Etas       = obj.Stations.SecondaryEta;
% Rnodes_all = obj.Stations.SecondaryNodes;
% num_ribs = length(Etas);
% N        = size(Rnodes_all, 1) / num_ribs;
% free_mask = ~ismembertol(Etas, obj.Stations.ConstrainedEta, 1e-9);
% REtas     = Etas(free_mask);
% keep_rows = repelem(free_mask(:), N);
% Rnodes    = Rnodes_all(keep_rows, :);
% 
% % generate attachment nodes
% for i = 1:length(REtas)
%     nodesi = obj.GetPos(REtas(i));
%     fe.Points(end+1) = ads.fe.Point(nodesi, InputCoordSys=CS, isAttachment=true); % TODO Check isAttachment?
%     fe.Points(end).Note = "AttachmentNode";
%     if strlength(opts.PointName) > 0
%         fe.Points(end).Name = opts.PointName + "_N" + i;
%     end
%     flat = Rnodes(1+(i-1)*N : i*N, :);
%     idx  = unique(flat(:)');
%     REFC = 123456;
%     Wti  = 1.0 / numel(idx);
%     Ci   = 123456;
%     fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end), REFC, Wti, Ci, fe.Points(idx));
% end
% 
% % constraints - TODO
% if ~isempty(obj.Stations.ConstrainedNodes)
%     n_per_station = size(obj.Stations.ConstrainedNodes, 1);
%     for j = 1:length(obj.Stations.ConstrainedEta)
%         nodeCon = obj.GetPos(obj.Stations.ConstrainedEta(j));
%         fe.Points(end+1) = ads.fe.Point(nodeCon, InputCoordSys=CS, isAttachment=true);
%         fe.Points(end).Note = "AttachmentNode";
%         if strlength(opts.PointName) > 0
%             fe.Points(end).Name = opts.PointName + "_C" + j;
%         end
%         for i = 1:n_per_station
%             fe.RigidBars(end+1) = ads.fe.RigidBar( ...
%                 fe.Points(end), fe.Points(obj.Stations.ConstrainedNodes(i,j)));
%         end
%     end
%     Etas = sort([REtas, obj.Stations.ConstrainedEta]);
% end
% 
% end


% function [fe,Etas] = shell2fe(obj,baffOpts,opts)
% arguments
%     obj
%     baffOpts = ads.baff.BaffOpts();
%     opts.PointName string = ""
% end
% %SHELL2FE baff shell to fe component
% fe = ads.fe.Component();
% fe.Name = obj.Name;
% fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
% CS = fe.CoordSys(1);
% 
% if ~issorted([obj.Stations.Eta])
%     error('shell stations must be in assending order with respect to Eta')
% end
% 
% nodes = obj.Stations.Nodes;
% 
% for i = 1:length(nodes)
%     fe.Points(i) = ads.fe.Point(nodes(i,:),InputCoordSys=CS);
% end
% 
% fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1));
% 
% shells = obj.Stations.Shell;
% for i = 1:length(shells)
%     fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),fe.Materials(end),shells(i).Thickness);
% end
% 
% Etas = obj.Stations.SecondaryEta;
% Rnodes_all = obj.Stations.SecondaryNodes;
% num_ribs = length(Etas);
% N = size(Rnodes_all,1) / num_ribs;
% free_mask = ~ismembertol(Etas, obj.Stations.ConstrainedEta, 1e-9);
% REtas = Etas(free_mask);
% keep_rows = repelem(free_mask(:), N);
% Rnodes = Rnodes_all(keep_rows, :);
% 
% n_free = numel(REtas);
% n_con = length(obj.Stations.ConstrainedEta);
% 
% combined_etas = [REtas(:); obj.Stations.ConstrainedEta(:)];
% combined_type = [zeros(n_free,1); ones(n_con,1)];
% combined_orig = [(1:n_free)'; (1:n_con)'];
% 
% [combined_etas, perm] = sort(combined_etas);
% combined_type = combined_type(perm);
% combined_orig = combined_orig(perm);
% 
% n_per_station = size(obj.Stations.ConstrainedNodes, 1);
% free_disp = 0;
% con_disp = 0;
% 
% for k = 1:length(combined_etas)
%     eta_k = combined_etas(k);
%     orig_idx = combined_orig(k);
%     nodes_k = obj.GetPos(eta_k);
% 
%     fe.Points(end+1) = ads.fe.Point(nodes_k, InputCoordSys=CS, isAttachment=true);
%     fe.Points(end).Note = "AttachmentNode";
% 
%     if combined_type(k) == 0
%         free_disp = free_disp + 1;
%         if strlength(opts.PointName) > 0
%             fe.Points(end).Name = opts.PointName + "_N" + free_disp;
%         end
%         flat = Rnodes(1+(orig_idx-1)*N : orig_idx*N, :);
%         idx = unique(flat(:)');
%         REFC = 123456;
%         Wti = 1.0 / numel(idx);
%         Ci = 123456;
%         fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end), REFC, Wti, Ci, fe.Points(idx));
%     else
%         con_disp = con_disp + 1;
%         if strlength(opts.PointName) > 0
%             fe.Points(end).Name = opts.PointName + "_C" + con_disp;
%         end
%         for i = 1:n_per_station
%             fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(end), fe.Points(obj.Stations.ConstrainedNodes(i, orig_idx)));
%         end
%     end
% end
% 
% Etas = combined_etas(:)';
% 
% end


function [fe,Etas] = shell2fe(obj,baffOpts,opts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
    opts.PointName string = ""
end
%SHELL2FE baff shell to fe component
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

if ~issorted([obj.Stations.Eta])
    error('shell stations must be in assending order with respect to Eta')
end

nodes = obj.Stations.Nodes;

for i = 1:length(nodes)
    fe.Points(i) = ads.fe.Point(nodes(i,:),InputCoordSys=CS);
end

fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1));

shells = obj.Stations.Shell;
for i = 1:length(shells)
    fe.Shells(end+1) = ads.fe.Shell.FromBaffStations(shells(i),fe.Points(shells(i).G),fe.Materials(end),shells(i).Thickness);
end

Etas = obj.Stations.SecondaryEta;
Rnodes_all = obj.Stations.SecondaryNodes;
num_ribs = length(Etas);
N = size(Rnodes_all,1) / num_ribs;
free_mask = ~ismembertol(Etas, obj.Stations.ConstrainedEta, 1e-9);
REtas = Etas(free_mask);
keep_rows = repelem(free_mask(:), N);
Rnodes = Rnodes_all(keep_rows, :);

n_free = numel(REtas);
n_con = length(obj.Stations.ConstrainedEta);

combined_etas = [REtas(:); obj.Stations.ConstrainedEta(:)];
combined_type = [zeros(n_free,1); ones(n_con,1)];
combined_orig = [(1:n_free)'; (1:n_con)'];

[combined_etas, perm] = sort(combined_etas);
combined_type = combined_type(perm);
combined_orig = combined_orig(perm);

n_per_station = size(obj.Stations.ConstrainedNodes, 1);
free_disp = 0;
con_disp = 0;

for k = 1:length(combined_etas)
    eta_k = combined_etas(k);
    orig_idx = combined_orig(k);
    nodes_k = obj.GetPos(eta_k);

    fe.Points(end+1) = ads.fe.Point(nodes_k, InputCoordSys=CS, isAttachment=true);
    fe.Points(end).Note = "AttachmentNode";

    if combined_type(k) == 0
        free_disp = free_disp + 1;
        if strlength(opts.PointName) > 0
            fe.Points(end).Name = opts.PointName + "_N" + free_disp;
        end
        flat = Rnodes(1+(orig_idx-1)*N : orig_idx*N, :);
        idx = unique(flat(:)');
        REFC = 123456;
        Wti = 1.0 / numel(idx);
        Ci = 123456;
        fe.RigidBodyElements(end+1) = ads.fe.RigidBodyElement(fe.Points(end), REFC, Wti, Ci, fe.Points(idx));
    else
        con_disp = con_disp + 1;
        if strlength(opts.PointName) > 0
            fe.Points(end).Name = opts.PointName + "_C" + con_disp;
        end
        for i = 1:n_per_station
            fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(end), fe.Points(obj.Stations.ConstrainedNodes(i, orig_idx)));
        end
    end
end

% --------------------------------------------------------------------
% Stringers (SecondaryBeams)
% --------------------------------------------------------------------
%   Each baff.station.LBeam in obj.Stations.SecondaryBeams becomes (N-1)
%   ads.fe.LBeam elements — one per inter-station segment — that share
%   their End A / End B GRIDs with skin (and rib) nodes through the
%   pre-built fe.Points entries indexed by sb.BoundNodes.
%
%   Material is added once per stringer; downstream UpdateID will assign
%   unique MIDs. If you start using many stringers with shared materials,
%   add a dedup step here (compare against existing fe.Materials).
% --------------------------------------------------------------------
if ~isempty(obj.Stations.SecondaryBeams)
    for s = 1:numel(obj.Stations.SecondaryBeams)
        sb = obj.Stations.SecondaryBeams(s);

        % Material for this stringer
        mat_fe = ads.fe.Material.FromBaffMat(sb.Mat(1));
        fe.Materials(end+1) = mat_fe;

        % Skin/rib Points the stringer shares (one per baff station)
        bound_pts = fe.Points(sb.BoundNodes);
        bound_pts = bound_pts(:);

        % (N-1) ads.fe.LBeam elements per stringer
        lbeams = ads.fe.LBeam.FromBaffLBeam(sb, bound_pts, mat_fe);
        for k = 1:numel(lbeams)
            fe.LBeams(end+1) = lbeams(k);
        end
    end
end

Etas = combined_etas(:)';

end