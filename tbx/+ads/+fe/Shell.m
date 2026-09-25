% classdef Shell < ads.fe.Element
%     %BEAM Summary of this class goes here
%     %   Detailed explanation goes here

%     % - TODO- Thickness must equal sum of ply layers 'T'
%     properties
%         EID double = nan;
%         PID double = nan;
%         G ads.fe.Point=ads.fe.Point.empty(0,1);
%         Mat ads.fe.Material = ads.fe.Material.empty;
%         Thickness double {mustBePositive}= 1e-6;

%         ExportType string {mustBeMember(ExportType,{'PCOMP','PSHELL'})} = "PSHELL";        
%         ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
%         ExportLongFormat logical = false; %maybe true
%     end

%     methods
%         function obj = Shell(G,Mat,Thickness,opts)
%             arguments
%                 G (4,1) ads.fe.Point
%                 Mat ads.fe.Material 
%                 Thickness double
%                 opts.ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
%                 opts.ExportType string {mustBeMember(opts.ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
%             end
%             obj.G=G;
%             obj.Mat = Mat;
%             obj.Thickness = Thickness;
%             obj.ply = opts.ply;
%             obj.ExportType = opts.ExportType;
%         end

%         % - TODO -- shell mass estimation not implemented
%         function m = GetMass(obj)
%             m = zeros(size(obj));
%             warning('shell mass estimation not implemented')
%         end

%         function plt_obj = drawElement(obj)
%             arguments
%                 obj
%             end
%             if isempty(obj)
%                 plt_obj = [];
%                 return
%             end
%             for i = 1:length(obj)
%                 nodes = [obj(i).G];
%                 Xs = [nodes.GlobalPos];
%                 if obj(i).ExportType == "PCOMP"
%                     plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'r');
%                     plt_obj(i).EdgeColor = 'r';
%                     plt_obj(i).FaceAlpha = 0.06;
%                     plt_obj(i).Tag = "CQUAD4 (PCOMP)";
%                 elseif obj(i).ExportType == "PSHELL"
%                     % plt_obj(i) = plot3(Xs(1,:),Xs(2,:),Xs(3,:),'k');
%                     plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'y');
%                     plt_obj(i).EdgeColor = 'k';
%                     plt_obj(i).FaceAlpha = 0.06;
%                     plt_obj(i).Tag = "CQUAD4 (PSHELL)";
%                 end
%             end
%         end

%         function ids = UpdateID(obj,ids)
%             for i = 1:length(obj)
%                 obj(i).EID = ids.EID;
%                 ids.EID = ids.EID + 1;
%                 obj(i).PID = ids.PID;
%                 ids.PID = ids.PID + 1;
%             end
%         end

%         function Export(obj,fid)
%             if ~isempty(obj)
%                 % print CQUAD4 elements
%                 mni.printing.bdf.writeComment(fid,"CQUAD4: Defines a QUADRILATERAL element.");
%                 mni.printing.bdf.writeColumnDelimiter(fid,"short")
%                 for i = 1:length(obj)
%                     tmpCard = mni.printing.cards.CQUAD4(obj(i).EID,obj(i).PID,[obj(i).G.ID]);
%                     tmpCard.writeToFile(fid);
%                 end

%                 % print PCOMP/PSHELL elements
%                 names = ["PCOMP","PSHELL"];
%                 for i = 1:length(names)
%                     idx= [obj.ExportType] == names(i);
%                     if nnz(idx)>0
%                         switch names(i)
%                             case "PCOMP"
%                                 obj(idx).ExportToPCOMP(fid);
%                             case "PSHELL"
%                                 obj(idx).ExportToPSHELL(fid);
%                         end
%                     end
%                 end
%             end
%         end

%         function ExportToPCOMP(obj,fid)
%             % print PCOMP elements
%             mni.printing.bdf.writeComment(fid,"PCOMP : Defines the properties of an n-ply composite material laminate.");
%             mni.printing.bdf.writeColumnDelimiter(fid,"long")
%             for i = 1:length(obj)

%                 plyLayers = mni.printing.cards.PlyLayer.empty;
%                 for j = 1:length(obj(i).ply.Layers)
%                     plyLayers(j) = obj(i).ply.Layers(j).ToMatran();
%                 end

%                 tmpCard = mni.printing.cards.PCOMP(obj(i).PID,obj(i).ply.Z0,obj(i).ply.NSM,obj(i).ply.SB,obj(i).ply.FT,obj(i).ply.TREF,obj(i).ply.GE,obj(i).ply.LAM,plyLayers);

%                 tmpCard.LongFormat = obj.ExportLongFormat;
%                 tmpCard.writeToFile(fid);
%             end
%         end

%         function ExportToPSHELL(obj,fid)
%             % print PSHELL elements
%             mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
%             mni.printing.bdf.writeColumnDelimiter(fid,"long")
%             for i = 1:length(obj)
%                 tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID,[],obj(i).Mat.ID);
%                 tmpCard.LongFormat = obj.ExportLongFormat;
%                 tmpCard.writeToFile(fid);

%             end
%         end


%     end
%     methods(Static)
%         function obj = FromBaffStations(st,G,Mat,Thickness)
%             arguments
%                 st baff.station.ShellStation.Shell
%                 G(4,1) ads.fe.Point
%                 Mat ads.fe.Material
%                 Thickness double
%             end

%             if st.ExportType == "PCOMP" 
%                 PlyDef = ads.fe.PlyDefinition.FromBaffStation(st.ply);
%             elseif st.ExportType == "PSHELL" 
%                 PlyDef = ads.fe.PlyDefinition.empty;
%             end

%             obj = ads.fe.Shell(G,Mat,Thickness,"ExportType",st.ExportType,"ply",PlyDef);

%         end
%     end

% end

% classdef Shell < ads.fe.Element
%     %SHELL Shell element with optional composite laminate, supporting
%     %ABD computation, per-ply strain/stress recovery, and visualisation
%     %of structural response across time histories (static, envelope, or
%     %animated) for composite tailoring workflows.
% 
%     % - TODO - Thickness must equal sum of ply layers 'T'
%     properties
%         EID double = nan;
%         PID double = nan;
%         G ads.fe.Point=ads.fe.Point.empty(0,1);
%         Mat ads.fe.Material = ads.fe.Material.empty;
%         Thickness double {mustBePositive}= 1e-6;
% 
%         ExportType string {mustBeMember(ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
%         ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
%         ExportLongFormat logical = false;
%     end
% 
%     methods
%         function obj = Shell(G,Mat,Thickness,opts)
%             arguments
%                 G (4,1) ads.fe.Point
%                 Mat ads.fe.Material
%                 Thickness double
%                 opts.ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
%                 opts.ExportType string {mustBeMember(opts.ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
%             end
%             obj.G=G;
%             obj.Mat = Mat;
%             obj.Thickness = Thickness;
%             obj.ply = opts.ply;
%             obj.ExportType = opts.ExportType;
%         end
% 
%         function m = GetMass(obj)
%             m = zeros(size(obj));
%             warning('shell mass estimation not implemented')
%         end
% 
%         function plt_obj = drawElement(obj)
%             arguments
%                 obj
%             end
%             if isempty(obj)
%                 plt_obj = [];
%                 return
%             end
%             for i = 1:length(obj)
%                 nodes = [obj(i).G];
%                 Xs = [nodes.GlobalPos];
%                 if obj(i).ExportType == "PCOMP"
%                     plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'r');
%                     plt_obj(i).EdgeColor = 'r';
%                     plt_obj(i).FaceAlpha = 0.06;
%                     plt_obj(i).Tag = "CQUAD4 (PCOMP)";
%                 elseif obj(i).ExportType == "PSHELL"
%                     plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'y');
%                     plt_obj(i).EdgeColor = 'k';
%                     plt_obj(i).FaceAlpha = 0.06;
%                     plt_obj(i).Tag = "CQUAD4 (PSHELL)";
%                 end
%             end
%         end
% 
%         function ids = UpdateID(obj,ids)
%             for i = 1:length(obj)
%                 obj(i).EID = ids.EID;
%                 ids.EID = ids.EID + 1;
%                 obj(i).PID = ids.PID;
%                 ids.PID = ids.PID + 1;
%             end
%         end
% 
%         function Export(obj,fid)
%             if ~isempty(obj)
%                 mni.printing.bdf.writeComment(fid,"CQUAD4: Defines a QUADRILATERAL element.");
%                 mni.printing.bdf.writeColumnDelimiter(fid,"short")
%                 for i = 1:length(obj)
%                     tmpCard = mni.printing.cards.CQUAD4(obj(i).EID,obj(i).PID,[obj(i).G.ID]);
%                     tmpCard.writeToFile(fid);
%                 end
%                 names = ["PCOMP","PSHELL"];
%                 for i = 1:length(names)
%                     idx= [obj.ExportType] == names(i);
%                     if nnz(idx)>0
%                         switch names(i)
%                             case "PCOMP"
%                                 obj(idx).ExportToPCOMP(fid);
%                             case "PSHELL"
%                                 obj(idx).ExportToPSHELL(fid);
%                         end
%                     end
%                 end
%             end
%         end
% 
%         function ExportToPCOMP(obj,fid)
%             mni.printing.bdf.writeComment(fid,"PCOMP : Defines the properties of an n-ply composite material laminate.");
%             mni.printing.bdf.writeColumnDelimiter(fid,"long")
%             for i = 1:length(obj)
%                 plyLayers = mni.printing.cards.PlyLayer.empty;
%                 for j = 1:length(obj(i).ply.Layers)
%                     plyLayers(j) = obj(i).ply.Layers(j).ToMatran();
%                 end
%                 tmpCard = mni.printing.cards.PCOMP(obj(i).PID,obj(i).ply.Z0,obj(i).ply.NSM,obj(i).ply.SB,obj(i).ply.FT,obj(i).ply.TREF,obj(i).ply.GE,obj(i).ply.LAM,plyLayers);
%                 tmpCard.LongFormat = obj.ExportLongFormat;
%                 tmpCard.writeToFile(fid);
%             end
%         end
% 
%         function ExportToPSHELL(obj,fid)
%             mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
%             mni.printing.bdf.writeColumnDelimiter(fid,"long")
%             for i = 1:length(obj)
%                 tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID,[],obj(i).Mat.ID);
%                 tmpCard.LongFormat = obj.ExportLongFormat;
%                 tmpCard.writeToFile(fid);
%             end
%         end
% 
%         function ABD = getABD(obj)
%             %GETABD Returns the laminate stiffness matrix [A B; B D]
%             %(6x6) for each shell, in element-local coordinates.
%             % Single shell -> 6x6.  Array of N shells -> 6x6xN.
%             if length(obj) > 1
%                 ABD = zeros(6, 6, length(obj));
%                 for i = 1:length(obj)
%                     ABD(:,:,i) = obj(i).getABD();
%                 end
%                 return
%             end
%             lam = obj.getLaminateData();
%             ABD = lam.ABD;
%         end
% 
%         function strains = solveStrains(obj, N, M)
%             %SOLVESTRAINS Per-element strain solve for one shell over one
%             %or many load states.
%             %
%             % Inputs:
%             %   N : 3xnT membrane forces  [Nx; Ny; Nxy] (per unit length)
%             %   M : 3xnT bending moments  [Mx; My; Mxy] (per unit length)
%             %   (Both in element-local coordinates, same convention as
%             %   NASTRAN QUAD4 force output.)
%             %
%             % Output (struct):
%             %   eps0     : 3xnT      mid-plane strains   (element frame)
%             %   kappa    : 3xnT      curvatures
%             %   z        : 3xnPly    z-coords [bottom; mid; top] per ply
%             %   theta    : 1xnPly    ply angles (deg)
%             %   eps_xy   : 3x3xnPlyxnT element-frame ply strains
%             %   eps_12   : 3x3xnPlyxnT material-frame ply strains
%             %   sig_12   : 3x3xnPlyxnT material-frame ply stresses
%             %   (eps_xy/eps_12/sig_12: dim1 = [exx;eyy;exy] or [e1;e2;g12],
%             %    dim2 = [bot,mid,top], dim3 = ply, dim4 = time)
%             arguments
%                 obj (1,1)
%                 N (3,:) double
%                 M (3,:) double
%             end
%             nT = size(N,2);
%             if size(M,2) ~= nT
%                 error('ads:fe:Shell:solveStrains:DimMismatch', ...
%                     'N and M must have the same number of time columns.');
%             end
% 
%             lam = obj.getLaminateData();
%             eps_curv = lam.abd * [N; M];          % 6xnT
%             eps0  = eps_curv(1:3, :);
%             kappa = eps_curv(4:6, :);
% 
%             nPly = size(lam.z, 2);
%             eps_xy = zeros(3, 3, nPly, nT);
%             eps_12 = zeros(3, 3, nPly, nT);
%             sig_12 = zeros(3, 3, nPly, nT);
%             for k = 1:nPly
%                 Ts = lam.Tstrain(:,:,k);
%                 Qk = lam.Q(:,:,k);
%                 for r = 1:3              % 1=bot, 2=mid, 3=top
%                     z_kr = lam.z(r, k);
%                     e_xy = eps0 + z_kr * kappa;          % 3xnT
%                     e_12 = Ts * e_xy;                    % 3xnT
%                     s_12 = Qk * e_12;                    % 3xnT
%                     eps_xy(:, r, k, :) = e_xy;
%                     eps_12(:, r, k, :) = e_12;
%                     sig_12(:, r, k, :) = s_12;
%                 end
%             end
% 
%             strains.eps0   = eps0;
%             strains.kappa  = kappa;
%             strains.z      = lam.z;
%             strains.theta  = lam.theta;
%             strains.eps_xy = eps_xy;
%             strains.eps_12 = eps_12;
%             strains.sig_12 = sig_12;
%         end
% 
%         function patches = plotResponse(obj, QuadForce, NV)
%             %PLOTRESPONSE Colour-maps shell elements by a chosen scalar
%             %derived from a QUAD4 force time history (output of
%             %read_dynamic). Supports static (one time), envelope (worst
%             %over time), and animate (looping) modes.
%             %
%             % Inputs:
%             %   QuadForce : struct with fields EIDs, Nx, Ny, Nxy, Mx, My,
%             %               Mxy (each nT x nQuad). Output of read_dynamic.
%             %
%             % Name-Value options:
%             %   'Mode'        : 'static' | 'envelope' (default) | 'animate'
%             %   'Quantity'    : scalar to plot. One of:
%             %                   forces : 'Nx','Ny','Nxy','Mx','My','Mxy'
%             %                   element-frame strain : 'eps_xx','eps_yy','gamma_xy'
%             %                   material-frame strain: 'eps_1','eps_2','gamma_12'
%             %                   material-frame stress: 'sig_1','sig_2','tau_12'
%             %                   failure indices      : 'TsaiHill','MaxStrain','MaxStress'
%             %                   default: 'MaxStrain'
%             %   'TimeIndex'   : (static) time row to use. Default = peak |Z-disp|
%             %                   if Displacement provided, else floor(nT/2).
%             %   'PlyIndex'    : []  -> worst across all plies (default)
%             %                   k   -> only ply k
%             %   'ZLocation'   : 'worst' (default) | 'top' | 'mid' | 'bottom'
%             %                   For 'worst', considers ply top+bottom (skips mid).
%             %   'Allowables'  : struct of overrides applied per ply to
%             %                   getAllowables(). e.g. struct('eXt',5e-3,'eXc',4e-3).
%             %   'CLim'        : [cMin cMax] manual colour limits. Default
%             %                   auto: symmetric about 0 for signed scalars,
%             %                   [0,max] for failure indices.
%             %   'Colormap'    : 'parula' (default), 'turbo', diverging map,
%             %                   or Nx3 RGB.
%             %   'Axes'        : axes handle. Default: gca.
%             %   --- animate-only ---
%             %   'Displacement': Displacement struct from read_dynamic
%             %                   (.IDs, .X, .Y, .Z). If provided, mesh
%             %                   deforms each frame. Optional.
%             %   'TimeVec'     : nT x 1 time values for frame titles.
%             %   'Stride'      : (animate) step every N-th time index.
%             %   'OutputFile'  : (animate) '.mp4'|'.avi'|'.gif'. Empty = no save.
%             %   'FrameRate'   : (animate) default 30.
%             %   'Scale'       : deformation scale factor. Default 1.
%             arguments
%                 obj
%                 QuadForce struct
%                 NV.Mode (1,:) char {mustBeMember(NV.Mode, {'static','envelope','animate'})} = 'envelope'
%                 NV.Quantity (1,:) char = 'MaxStrain'
%                 NV.TimeIndex double = []
%                 NV.PlyIndex double = []
%                 NV.ZLocation (1,:) char {mustBeMember(NV.ZLocation,{'top','mid','bottom','worst'})} = 'worst'
%                 NV.Allowables struct = struct()
%                 NV.CLim double = []
%                 NV.Colormap = 'parula'
%                 NV.Axes = []
%                 NV.Displacement struct = struct()
%                 NV.TimeVec double = []
%                 NV.Stride (1,1) double = 1
%                 NV.OutputFile (1,:) char = ''
%                 NV.FrameRate (1,1) double = 30
%                 NV.Scale (1,1) double = 1
%             end
% 
%             % ---- map shell EIDs to QuadForce columns ----
%             [~, qi] = ismember([obj.EID], QuadForce.EIDs);
%             valid = qi > 0;
%             if ~any(valid)
%                 warning('plotResponse:NoMatch','No shell EIDs match QuadForce.EIDs.');
%                 patches = gobjects(0); return
%             end
%             nT = size(QuadForce.Mx, 1);
% 
%             % ---- precompute laminate data + per-ply allowables ----
%             lamData = cell(length(obj),1);
%             allowables = cell(length(obj),1);
%             for i = 1:length(obj)
%                 if valid(i)
%                     lamData{i} = obj(i).getLaminateData();
%                     allowables{i} = i_perPlyAllowables(lamData{i}, NV.Allowables);
%                 end
%             end
% 
%             % ---- branch on mode ----
%             switch NV.Mode
%                 case 'static'
%                     t_idx = NV.TimeIndex;
%                     if isempty(t_idx)
%                         if isfield(NV.Displacement,'Z') && ~isempty(NV.Displacement.Z)
%                             [~, t_idx] = max(max(abs(NV.Displacement.Z), [], 2));
%                         else
%                             t_idx = max(1, floor(nT/2));
%                         end
%                     end
%                     scalars = nan(length(obj),1);
%                     for i = 1:length(obj)
%                         if ~valid(i), continue; end
%                         N_i = [QuadForce.Nx(t_idx, qi(i)); QuadForce.Ny(t_idx, qi(i)); QuadForce.Nxy(t_idx, qi(i))];
%                         M_i = [QuadForce.Mx(t_idx, qi(i)); QuadForce.My(t_idx, qi(i)); QuadForce.Mxy(t_idx, qi(i))];
%                         scalars(i) = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
%                     end
%                     titleStr = sprintf('%s @ t-index %d', NV.Quantity, t_idx);
%                     patches = i_drawColored(obj, scalars, NV, titleStr);
% 
%                 case 'envelope'
%                     scalars = nan(length(obj),1);
%                     for i = 1:length(obj)
%                         if ~valid(i), continue; end
%                         N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
%                         M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
%                         scalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
%                     end
%                     titleStr = sprintf('%s — envelope over %d time steps', NV.Quantity, nT);
%                     patches = i_drawColored(obj, scalars, NV, titleStr);
% 
%                 case 'animate'
%                     patches = i_animateResponse(obj, QuadForce, qi, valid, lamData, allowables, NV);
%             end
%         end
% 
%     end
% 
%     methods(Access = private)
%         function lam = getLaminateData(obj)
%             %getLaminateData Precomputes per-element laminate quantities.
%             % Returns struct with ABD, abd, z(3xnPly: bot/mid/top), theta,
%             % Q (material-frame), Qbar (element-frame), Tstrain (R*T*Rinv
%             % strain rotation matrix per ply), Material (per ply), t.
%             if obj.ExportType == "PCOMP"
%                 layers = obj.ply.Layers;
%                 if isempty(layers)
%                     error('ads:fe:Shell:getLaminateData:NoPlies', ...
%                         'Shell EID=%d is PCOMP but has no ply layers.', obj.EID);
%                 end
%                 nPly = length(layers);
%                 t = zeros(1, nPly);
%                 theta = zeros(1, nPly);
%                 mats = repmat(ads.fe.Material.empty(1,0), 1, 0);
%                 mats = cell(1, nPly);
%                 for k = 1:nPly
%                     pl = layers(k);
%                     t(k) = pl.T;
%                     theta(k) = pl.THETA;
%                     mats{k} = pl.Material;
%                 end
%             else  % PSHELL — treat as single layer
%                 if isempty(obj.Mat) || ~isscalar(obj.Mat)
%                     error('ads:fe:Shell:getLaminateData:NoMaterial', ...
%                         'PSHELL shell EID=%d has no Mat assigned.', obj.EID);
%                 end
%                 nPly = 1;
%                 t = obj.Thickness;
%                 theta = 0;
%                 mats = {obj.Mat};
%             end
% 
%             Q = zeros(3,3,nPly);
%             Qbar = zeros(3,3,nPly);
%             Tstrain = zeros(3,3,nPly);
%             for k = 1:nPly
%                 Q(:,:,k) = ads.fe.Shell.i_Q_planeStress(mats{k});
%                 Qbar(:,:,k) = ads.fe.Shell.i_rotateQ(Q(:,:,k), theta(k));
%                 Tstrain(:,:,k) = ads.fe.Shell.i_Tstrain(theta(k));
%             end
% 
%             h = sum(t);
%             z_bound = -h/2 + [0, cumsum(t)];   % 1 x (nPly+1)
%             z = zeros(3, nPly);
%             z(1,:) = z_bound(1:end-1);                          % bottom
%             z(2,:) = (z_bound(1:end-1) + z_bound(2:end))/2;     % mid
%             z(3,:) = z_bound(2:end);                            % top
% 
%             A = zeros(3,3); B = zeros(3,3); D = zeros(3,3);
%             for k = 1:nPly
%                 Qb = Qbar(:,:,k);
%                 A = A + Qb*(z_bound(k+1)   - z_bound(k));
%                 B = B + Qb*(z_bound(k+1)^2 - z_bound(k)^2)/2;
%                 D = D + Qb*(z_bound(k+1)^3 - z_bound(k)^3)/3;
%             end
%             ABD = [A B; B D];
% 
%             lam.ABD = ABD;
%             lam.abd = inv(ABD);
%             lam.z = z;
%             lam.theta = theta;
%             lam.Q = Q;
%             lam.Qbar = Qbar;
%             lam.Tstrain = Tstrain;
%             lam.Material = mats;
%             lam.t = t;
%         end
%     end
% 
%     methods(Static)
%         function obj = FromBaffStations(st,G,Mat,Thickness)
%             arguments
%                 st baff.station.ShellStation.Shell
%                 G(4,1) ads.fe.Point
%                 Mat ads.fe.Material
%                 Thickness double
%             end
%             if st.ExportType == "PCOMP"
%                 PlyDef = ads.fe.PlyDefinition.FromBaffStation(st.ply);
%             elseif st.ExportType == "PSHELL"
%                 PlyDef = ads.fe.PlyDefinition.empty;
%             end
%             obj = ads.fe.Shell(G,Mat,Thickness,"ExportType",st.ExportType,"ply",PlyDef);
%         end
%     end
% 
%     methods (Static, Access = private)
%         function Q = i_Q_planeStress(mat)
%             %i_Q_planeStress Plane-stress reduced stiffness for one
%             %material. Handles both MAT1 (isotropic) and MAT8 (orthotropic).
%             if mat.MAT == "MAT8"
%                 E1 = mat.E1;  E2 = mat.E2;
%                 nu12 = mat.NU12;  G12 = mat.G12;
%                 if any(isnan([E1, E2, nu12, G12]))
%                     error('ads:fe:Shell:BadMat8', ...
%                         'MAT8 material "%s" is missing E1/E2/NU12/G12.', mat.Name);
%                 end
%                 nu21  = E2/E1 * nu12;
%                 denom = 1 - nu12*nu21;
%                 Q11 = E1   / denom;
%                 Q22 = E2   / denom;
%                 Q12 = nu12 * E2 / denom;
%                 Q66 = G12;
%                 Q = [Q11 Q12 0;  Q12 Q22 0;  0 0 Q66];
%             else  % MAT1
%                 E  = mat.E;
%                 nu = mat.nu;
%                 denom = 1 - nu^2;
%                 Q11 = E  / denom;
%                 Q12 = nu * E / denom;
%                 Q66 = E  / (2 * (1 + nu));
%                 Q = [Q11 Q12 0;  Q12 Q11 0;  0 0 Q66];
%             end
%         end
% 
%         function Qbar = i_rotateQ(Q, theta_deg)
%             %i_rotateQ Rotate reduced stiffness Q from material frame
%             %(1-2) to element-local frame (x-y) by ply angle theta (deg).
%             Q11 = Q(1,1); Q22 = Q(2,2); Q12 = Q(1,2); Q66 = Q(3,3);
%             m = cosd(theta_deg);  n = sind(theta_deg);
%             m2 = m^2; n2 = n^2; m4 = m^4; n4 = n^4; mn2 = m2*n2;
%             Qbar11 = Q11*m4 + 2*(Q12 + 2*Q66)*mn2 + Q22*n4;
%             Qbar22 = Q11*n4 + 2*(Q12 + 2*Q66)*mn2 + Q22*m4;
%             Qbar12 = (Q11 + Q22 - 4*Q66)*mn2 + Q12*(n4 + m4);
%             Qbar66 = (Q11 + Q22 - 2*Q12 - 2*Q66)*mn2 + Q66*(n4 + m4);
%             Qbar16 = (Q11 - Q12 - 2*Q66)*n*m^3 - (Q22 - Q12 - 2*Q66)*m*n^3;
%             Qbar26 = (Q11 - Q12 - 2*Q66)*m*n^3 - (Q22 - Q12 - 2*Q66)*n*m^3;
%             Qbar = [Qbar11 Qbar12 Qbar16;
%                     Qbar12 Qbar22 Qbar26;
%                     Qbar16 Qbar26 Qbar66];
%         end
% 
%         function Tstr = i_Tstrain(theta_deg)
%             %i_Tstrain Strain transformation matrix mapping element-frame
%             %engineering strain [exx;eyy;gxy] to material-frame engineering
%             %strain [e1;e2;g12]. Equals R*T*inv(R) where R=diag(1,1,2)
%             %(Reuter) and T is the standard 2D stress rotation.
%             m = cosd(theta_deg);  n = sind(theta_deg);
%             % equivalent simplified form of R*T*R^-1 for engineering strain:
%             Tstr = [ m^2,   n^2,   m*n;
%                      n^2,   m^2,  -m*n;
%                     -2*m*n, 2*m*n, m^2 - n^2];
%         end
%     end
% end
% 
% function al = i_perPlyAllowables(lam, overrides)
%     nPly = length(lam.Material);
%     al = cell(nPly, 1);
%     for k = 1:nPly
%         mat = lam.Material{k};
%         if ismethod(mat, 'getAllowables')
%             al{k} = mat.getAllowables(overrides);
%         else
%             % material doesn't expose getAllowables — fall back to raw fields
%             al{k} = struct('Xt',mat.Xt,'Xc',mat.Xc,'Yt',mat.Yt,'Yc',mat.Yc,'S',mat.S, ...
%                 'eXt',NaN,'eXc',NaN,'eYt',NaN,'eYc',NaN,'eS',NaN);
%         end
%     end
% end
% 
% function s = i_scalarOneState(N, M, lam, allowables, NV)
%     %i_scalarOneState One element, one time state -> one scalar.
%     q = NV.Quantity;
%     % --- raw forces ---
%     switch q
%         case 'Nx',  s = N(1); return
%         case 'Ny',  s = N(2); return
%         case 'Nxy', s = N(3); return
%         case 'Mx',  s = M(1); return
%         case 'My',  s = M(2); return
%         case 'Mxy', s = M(3); return
%     end
%     % --- need strain solve ---
%     eps_curv = lam.abd * [N; M];
%     eps0  = eps_curv(1:3);
%     kappa = eps_curv(4:6);
%     s = i_aggregateOverPlies(eps0, kappa, lam, allowables, NV);
% end
% 
% function s = i_scalarEnvelope(N, M, lam, allowables, NV)
%     %i_scalarEnvelope One element, full time history -> envelope scalar.
%     %N,M are 3xnT.
%     q = NV.Quantity;
%     % --- raw forces (no strain solve) ---
%     switch q
%         case 'Nx',  vals = N(1,:);
%         case 'Ny',  vals = N(2,:);
%         case 'Nxy', vals = N(3,:);
%         case 'Mx',  vals = M(1,:);
%         case 'My',  vals = M(2,:);
%         case 'Mxy', vals = M(3,:);
%         otherwise
%             vals = [];
%     end
%     if ~isempty(vals)
%         if i_isUnsignedFI(q)
%             s = max(vals);
%         else
%             [~, idx] = max(abs(vals));
%             s = vals(idx);
%         end
%         return
%     end
%     % --- strain solve (vectorised over time) ---
%     eps_curv = lam.abd * [N; M];           % 6 x nT
%     eps0  = eps_curv(1:3, :);
%     kappa = eps_curv(4:6, :);
%     % aggregate ply-by-ply, taking time max within each ply, then ply max
%     s_best = -Inf; abs_best = -Inf;
%     if isempty(NV.PlyIndex)
%         ply_range = 1:size(lam.z, 2);
%     else
%         ply_range = NV.PlyIndex;
%     end
%     z_rows = i_zRows(NV.ZLocation);
%     use_max = i_isUnsignedFI(q);
%     for k = ply_range
%         Ts = lam.Tstrain(:,:,k);
%         Qk = lam.Q(:,:,k);
%         al_k = allowables{k};
%         for r = z_rows
%             z_kr = lam.z(r, k);
%             e_xy = eps0 + z_kr * kappa;     % 3 x nT
%             e_12 = Ts * e_xy;               % 3 x nT
%             s_12 = Qk * e_12;               % 3 x nT
%             vals = i_quantityFromState(q, e_xy, e_12, s_12, al_k);
%             if use_max
%                 v = max(vals);
%                 if v > s_best, s_best = v; end
%             else
%                 [vabs, idx] = max(abs(vals));
%                 if vabs > abs_best
%                     abs_best = vabs;
%                     s_best   = vals(idx);
%                 end
%             end
%         end
%     end
%     s = s_best;
% end
% 
% function s = i_aggregateOverPlies(eps0, kappa, lam, allowables, NV)
%     %Aggregate ply-by-ply for a single time state.
%     q = NV.Quantity;
%     if isempty(NV.PlyIndex)
%         ply_range = 1:size(lam.z, 2);
%     else
%         ply_range = NV.PlyIndex;
%     end
%     z_rows = i_zRows(NV.ZLocation);
%     use_max = i_isUnsignedFI(q);
%     s_best = -Inf; abs_best = -Inf;
%     for k = ply_range
%         Ts = lam.Tstrain(:,:,k);
%         Qk = lam.Q(:,:,k);
%         al_k = allowables{k};
%         for r = z_rows
%             z_kr = lam.z(r, k);
%             e_xy = eps0 + z_kr * kappa;
%             e_12 = Ts * e_xy;
%             s_12 = Qk * e_12;
%             v = i_quantityFromState(q, e_xy, e_12, s_12, al_k);
%             if use_max
%                 if v > s_best, s_best = v; end
%             else
%                 if abs(v) > abs_best
%                     abs_best = abs(v);
%                     s_best   = v;
%                 end
%             end
%         end
%     end
%     s = s_best;
% end
% 
% function vals = i_quantityFromState(q, e_xy, e_12, s_12, al)
%     %Compute the named quantity from element/ply state. Supports both
%     %scalar (3x1) and vectorised (3xnT) inputs; returns row vector.
%     switch q
%         case 'eps_xx',    vals = e_xy(1,:);
%         case 'eps_yy',    vals = e_xy(2,:);
%         case 'gamma_xy',  vals = e_xy(3,:);
%         case 'eps_1',     vals = e_12(1,:);
%         case 'eps_2',     vals = e_12(2,:);
%         case 'gamma_12',  vals = e_12(3,:);
%         case 'sig_1',     vals = s_12(1,:);
%         case 'sig_2',     vals = s_12(2,:);
%         case 'tau_12',    vals = s_12(3,:);
%         case 'TsaiHill',  vals = i_tsaiHill(s_12, al);
%         case 'MaxStrain', vals = i_maxStrainFI(e_12, al);
%         case 'MaxStress', vals = i_maxStressFI(s_12, al);
%         otherwise
%             error('plotResponse:UnknownQuantity', ...
%                 'Unknown Quantity "%s".', q);
%     end
% end
% 
% function fi = i_tsaiHill(s, al)
%     s11 = s(1,:); s22 = s(2,:); t12 = s(3,:);
%     X = al.Xt * ones(size(s11));  X(s11 < 0) = al.Xc;
%     Y = al.Yt * ones(size(s22));  Y(s22 < 0) = al.Yc;
%     if isnan(al.S) || al.S == 0
%         warning('TsaiHill:BadShearAllowable','Shear allowable S is NaN/0.');
%         fi = nan(size(s11)); return
%     end
%     fi = (s11./X).^2 + (s22./Y).^2 + (t12./al.S).^2 - (s11.*s22)./X.^2;
% end
% 
% function fi = i_maxStrainFI(e, al)
%     e1 = e(1,:); e2 = e(2,:); g12 = e(3,:);
%     fi1 = zeros(size(e1));  fi1(e1>=0) = e1(e1>=0)/al.eXt;  fi1(e1<0) = -e1(e1<0)/al.eXc;
%     fi2 = zeros(size(e2));  fi2(e2>=0) = e2(e2>=0)/al.eYt;  fi2(e2<0) = -e2(e2<0)/al.eYc;
%     fi3 = abs(g12) / al.eS;
%     fi = max([fi1; fi2; fi3], [], 1);
% end
% 
% function fi = i_maxStressFI(s, al)
%     s1 = s(1,:); s2 = s(2,:); t12 = s(3,:);
%     fi1 = zeros(size(s1));  fi1(s1>=0) = s1(s1>=0)/al.Xt;  fi1(s1<0) = -s1(s1<0)/al.Xc;
%     fi2 = zeros(size(s2));  fi2(s2>=0) = s2(s2>=0)/al.Yt;  fi2(s2<0) = -s2(s2<0)/al.Yc;
%     fi3 = abs(t12) / al.S;
%     fi = max([fi1; fi2; fi3], [], 1);
% end
% 
% function rows = i_zRows(loc)
%     switch loc
%         case 'bottom', rows = 1;
%         case 'mid',    rows = 2;
%         case 'top',    rows = 3;
%         case 'worst',  rows = [1 3];   % bottom and top (skip mid)
%     end
% end
% 
% function tf = i_isUnsignedFI(q)
%     tf = any(strcmp(q, {'TsaiHill','MaxStrain','MaxStress'}));
% end
% 
% % -------------------------------------------------------------------------
% 
% function patches = i_drawColored(obj, scalars, NV, titleStr)
%     %Draw shells coloured by per-element scalars. Returns patch handles.
%     if isempty(NV.Axes) || ~isgraphics(NV.Axes)
%         hAx = gca;
%     else
%         hAx = NV.Axes;
%     end
%     hold(hAx, 'on');
% 
%     [cLim, isFI] = i_resolveCLim(scalars, NV);
% 
%     patches = gobjects(length(obj), 1);
%     for i = 1:length(obj)
%         nodes = [obj(i).G];
%         if isempty(nodes) || isnan(scalars(i)), continue; end
%         Xs = [nodes.GlobalPos];   % 3 x 4
%         patches(i) = patch(hAx, ...
%             'XData', Xs(1,:)', 'YData', Xs(2,:)', 'ZData', Xs(3,:)', ...
%             'FaceColor', 'flat', 'CData', scalars(i), ...
%             'EdgeColor', [0.3 0.3 0.3], ...
%             'Tag', sprintf('Shell %d', obj(i).EID), 'UserData', obj(i));
%     end
% 
%     clim(hAx, cLim);
%     if ischar(NV.Colormap) || isstring(NV.Colormap)
%         colormap(hAx, char(NV.Colormap));
%     else
%         colormap(hAx, NV.Colormap);
%     end
%     cb = colorbar(hAx);
%     cb.Label.String = NV.Quantity;
%     axis(hAx, 'equal');
%     title(hAx, titleStr, 'Interpreter','none');
% 
%     % overlay a contour at FI=1 hint (text only — patches are per-element)
%     if isFI && cLim(2) >= 1
%         title(hAx, sprintf('%s   (FI=1 is the structural limit)', titleStr), 'Interpreter','none');
%     end
% end
% 
% function [cLim, isFI] = i_resolveCLim(scalars, NV)
%     isFI = i_isUnsignedFI(NV.Quantity);
%     if ~isempty(NV.CLim)
%         cLim = NV.CLim;  return
%     end
%     v = scalars(~isnan(scalars));
%     if isempty(v)
%         cLim = [-1, 1]; return
%     end
%     if isFI
%         cLim = [0, max(v)];
%         if cLim(2) == 0, cLim(2) = 1; end
%     else
%         vmax = max(abs(v));
%         if vmax == 0, vmax = 1; end
%         cLim = [-vmax, vmax];
%     end
% end
% 
% % -------------------------------------------------------------------------
% 
% function patches = i_animateResponse(obj, QuadForce, qi, valid, lamData, allowables, NV)
%     %Animate plotResponse. Loops over time, updates patch CData (and
%     %vertex coords if Displacement provided), optionally writes to file.
% 
%     nT = size(QuadForce.Mx, 1);
%     t_indices = 1:NV.Stride:nT;
%     nFrames = numel(t_indices);
%     if nFrames < 2
%         warning('plotResponse:animate:NoFrames','Stride/range yields <2 frames; falling back to envelope.');
%         patches = i_animateFallback(obj, QuadForce, qi, valid, lamData, allowables, NV);
%         return
%     end
% 
%     % ---- precompute envelope scalars to fix CLim consistently ----
%     if isempty(NV.CLim)
%         envScalars = nan(length(obj),1);
%         for i = 1:length(obj)
%             if ~valid(i), continue; end
%             N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
%             M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
%             envScalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
%         end
%         cLim = i_resolveCLim(envScalars, NV);
%     else
%         cLim = NV.CLim;
%     end
% 
%     % ---- initial draw (first time index) ----
%     NV0 = NV;  NV0.CLim = cLim;
%     t0 = t_indices(1);
%     scalars0 = nan(length(obj),1);
%     for i = 1:length(obj)
%         if ~valid(i), continue; end
%         N_i = [QuadForce.Nx(t0,qi(i)); QuadForce.Ny(t0,qi(i)); QuadForce.Nxy(t0,qi(i))];
%         M_i = [QuadForce.Mx(t0,qi(i)); QuadForce.My(t0,qi(i)); QuadForce.Mxy(t0,qi(i))];
%         scalars0(i) = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
%     end
%     patches = i_drawColored(obj, scalars0, NV0, sprintf('%s — animating', NV.Quantity));
% 
%     % undeformed vertex coordinates (3 x 4 x nElem) + node id mapping
%     [undefXYZ, di, hasDisp] = i_setupDeformation(obj, NV.Displacement);
%     if hasDisp
%         Dx = NV.Displacement.X;   % nT x nNodes
%         Dy = NV.Displacement.Y;
%         Dz = NV.Displacement.Z;
%     end
% 
%     % time vector for titles
%     if isempty(NV.TimeVec) || numel(NV.TimeVec) ~= nT
%         tVec = (1:nT)';
%         tLabel = @(k) sprintf('frame %d/%d', k, nFrames);
%     else
%         tVec = NV.TimeVec;
%         tLabel = @(k) sprintf('t = %.4g s   (frame %d/%d)', tVec(t_indices(k)), k, nFrames);
%     end
% 
%     hAx = ancestor(patches(find(isgraphics(patches),1,'first')), 'axes');
%     hFig = ancestor(hAx, 'figure');
%     title_h = get(hAx, 'Title');
% 
%     % output writer
%     writer = []; isGif = false;
%     outFile = NV.OutputFile;
%     if ~isempty(outFile)
%         [~,~,ext] = fileparts(outFile);
%         switch lower(ext)
%             case '.gif',  isGif = true;
%             case {'.mp4','.m4v'}
%                 writer = VideoWriter(outFile,'MPEG-4');
%                 writer.FrameRate = NV.FrameRate;
%                 open(writer);
%             case '.avi'
%                 writer = VideoWriter(outFile,'Motion JPEG AVI');
%                 writer.FrameRate = NV.FrameRate;
%                 open(writer);
%             otherwise
%                 error('plotResponse:animate:BadExt','Unrecognised output extension "%s".', ext);
%         end
%     end
%     cleanupObj = onCleanup(@() i_finalizeWriter(writer)); %#ok<NASGU>
% 
%     % ---- main loop ----
%     for k = 1:nFrames
%         t_idx = t_indices(k);
%         % update colors + (optionally) vertex positions
%         for i = 1:length(obj)
%             if ~valid(i) || ~isgraphics(patches(i)), continue; end
%             N_i = [QuadForce.Nx(t_idx,qi(i)); QuadForce.Ny(t_idx,qi(i)); QuadForce.Nxy(t_idx,qi(i))];
%             M_i = [QuadForce.Mx(t_idx,qi(i)); QuadForce.My(t_idx,qi(i)); QuadForce.Mxy(t_idx,qi(i))];
%             s_i = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
%             patches(i).CData = s_i;
%             if hasDisp
%                 X = squeeze(undefXYZ(:, :, i));    % 3 x 4
%                 valid_n = di(i,:) > 0;
%                 if any(valid_n)
%                     X(1, valid_n) = X(1, valid_n) + NV.Scale * Dx(t_idx, di(i, valid_n));
%                     X(2, valid_n) = X(2, valid_n) + NV.Scale * Dy(t_idx, di(i, valid_n));
%                     X(3, valid_n) = X(3, valid_n) + NV.Scale * Dz(t_idx, di(i, valid_n));
%                 end
%                 patches(i).XData = X(1,:)';
%                 patches(i).YData = X(2,:)';
%                 patches(i).ZData = X(3,:)';
%             end
%         end
%         clim(hAx, cLim);
%         title_h.String = sprintf('%s   %s', NV.Quantity, tLabel(k));
%         drawnow;
% 
%         if ~isempty(writer) || isGif
%             frame = getframe(hFig);
%             if ~isempty(writer)
%                 writeVideo(writer, frame);
%             else
%                 [A,map] = rgb2ind(frame.cdata, 256);
%                 if k == 1
%                     imwrite(A,map,outFile,'gif','LoopCount',Inf,'DelayTime',1/NV.FrameRate);
%                 else
%                     imwrite(A,map,outFile,'gif','WriteMode','append','DelayTime',1/NV.FrameRate);
%                 end
%             end
%         end
%     end
% end
% 
% function [undefXYZ, di, hasDisp] = i_setupDeformation(obj, Displacement)
%     %Build (3 x 4 x nElem) array of undeformed node coords and a (nElem x 4)
%     %matrix of column indices into Displacement.IDs for each shell's nodes.
%     nE = length(obj);
%     undefXYZ = zeros(3, 4, nE);
%     di = zeros(nE, 4);
%     hasDisp = isfield(Displacement,'IDs') && ~isempty(Displacement.IDs) ...
%               && isfield(Displacement,'X');
%     for i = 1:nE
%         nodes = [obj(i).G];
%         if isempty(nodes), continue; end
%         Xs = [nodes.GlobalPos];   % 3 x 4
%         % pad to 4 columns if a tri-shell or partial
%         if size(Xs,2) < 4
%             Xs = [Xs, repmat(Xs(:,end), 1, 4-size(Xs,2))];
%         end
%         undefXYZ(:,:,i) = Xs(:, 1:4);
%         if hasDisp
%             ids = arrayfun(@(p) p.ID, nodes(:));
%             ids = ids(:)';
%             if numel(ids) < 4, ids = [ids, repmat(ids(end), 1, 4-numel(ids))]; end
%             [~, idx] = ismember(ids, Displacement.IDs);
%             di(i, :) = idx(1:4);
%         end
%     end
% end
% 
% function i_finalizeWriter(writer)
%     if ~isempty(writer)
%         try, close(writer); catch, end
%     end
% end
% 
% function patches = i_animateFallback(obj, QuadForce, qi, valid, lamData, allowables, NV)
%     %Fallback: too few frames -> just do envelope plot.
%     scalars = nan(length(obj),1);
%     for i = 1:length(obj)
%         if ~valid(i), continue; end
%         N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
%         M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
%         scalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
%     end
%     patches = i_drawColored(obj, scalars, NV, sprintf('%s — envelope (animate fallback)', NV.Quantity));
% end

classdef Shell < ads.fe.Element
    %SHELL Shell element with optional composite laminate, supporting
    %ABD computation, per-ply strain/stress recovery, and visualisation
    %of structural response across time histories (static, envelope, or
    %animated) for composite tailoring workflows.

    % - TODO - Thickness must equal sum of ply layers 'T'
    properties
        EID double = nan;
        PID double = nan;
        G ads.fe.Point=ads.fe.Point.empty(0,1);
        Mat ads.fe.Material = ads.fe.Material.empty;
        Thickness double {mustBePositive}= 1e-6;

        ExportType string {mustBeMember(ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
        ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
        ExportLongFormat logical = false;
    end

    methods
        function obj = Shell(G,Mat,Thickness,opts)
            arguments
                G (4,1) ads.fe.Point
                Mat ads.fe.Material
                Thickness double
                opts.ply ads.fe.PlyDefinition = ads.fe.PlyDefinition;
                opts.ExportType string {mustBeMember(opts.ExportType,{'PCOMP','PSHELL'})} = "PSHELL";
            end
            obj.G=G;
            obj.Mat = Mat;
            obj.Thickness = Thickness;
            obj.ply = opts.ply;
            obj.ExportType = opts.ExportType;
        end

        function m = GetMass(obj)
            m = zeros(size(obj));
            warning('shell mass estimation not implemented')
        end

        function plt_obj = drawElement(obj)
            arguments
                obj
            end
            if isempty(obj)
                plt_obj = [];
                return
            end
            for i = 1:length(obj)
                nodes = [obj(i).G];
                Xs = [nodes.GlobalPos];
                if obj(i).ExportType == "PCOMP"
                    plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'r');
                    plt_obj(i).EdgeColor = 'r';
                    plt_obj(i).FaceAlpha = 0.06;
                    plt_obj(i).Tag = "CQUAD4 (PCOMP)";
                elseif obj(i).ExportType == "PSHELL"
                    plt_obj(i) = patch(Xs(1,:),Xs(2,:),Xs(3,:),'y');
                    plt_obj(i).EdgeColor = 'k';
                    plt_obj(i).FaceAlpha = 0.06;
                    plt_obj(i).Tag = "CQUAD4 (PSHELL)";
                end
            end
        end

        function ids = UpdateID(obj,ids)
            for i = 1:length(obj)
                obj(i).EID = ids.EID;
                ids.EID = ids.EID + 1;
                obj(i).PID = ids.PID;
                ids.PID = ids.PID + 1;
            end
        end

        function Export(obj,fid)
            if ~isempty(obj)
                mni.printing.bdf.writeComment(fid,"CQUAD4: Defines a QUADRILATERAL element.");
                mni.printing.bdf.writeColumnDelimiter(fid,"short")
                for i = 1:length(obj)
                    tmpCard = mni.printing.cards.CQUAD4(obj(i).EID,obj(i).PID,[obj(i).G.ID]);
                    tmpCard.writeToFile(fid);
                end
                names = ["PCOMP","PSHELL"];
                for i = 1:length(names)
                    idx= [obj.ExportType] == names(i);
                    if nnz(idx)>0
                        switch names(i)
                            case "PCOMP"
                                obj(idx).ExportToPCOMP(fid);
                            case "PSHELL"
                                obj(idx).ExportToPSHELL(fid);
                        end
                    end
                end
            end
        end

        function ExportToPCOMP(obj,fid)
            mni.printing.bdf.writeComment(fid,"PCOMP : Defines the properties of an n-ply composite material laminate.");
            mni.printing.bdf.writeColumnDelimiter(fid,"long")
            for i = 1:length(obj)
                plyLayers = mni.printing.cards.PlyLayer.empty;
                for j = 1:length(obj(i).ply.Layers)
                    plyLayers(j) = obj(i).ply.Layers(j).ToMatran();
                end
                tmpCard = mni.printing.cards.PCOMP(obj(i).PID,obj(i).ply.Z0,obj(i).ply.NSM,obj(i).ply.SB,obj(i).ply.FT,obj(i).ply.TREF,obj(i).ply.GE,obj(i).ply.LAM,plyLayers);
                tmpCard.LongFormat = obj.ExportLongFormat;
                tmpCard.writeToFile(fid);
            end
        end

        function ExportToPSHELL(obj,fid)
            mni.printing.bdf.writeComment(fid,"PSHELL : Defines the properties of a SHELL element.");
            mni.printing.bdf.writeColumnDelimiter(fid,"long")
            for i = 1:length(obj)
                tmpCard = mni.printing.cards.PSHELL(obj(i).PID,obj(i).Mat.ID,obj(i).Thickness,obj(i).Mat.ID,[],obj(i).Mat.ID);
                tmpCard.LongFormat = obj.ExportLongFormat;
                tmpCard.writeToFile(fid);
            end
        end

        % =================================================================
        %                       LAMINATE MECHANICS
        % =================================================================

        function ABD = getABD(obj, MaterialList)
            %GETABD Returns the laminate stiffness matrix [A B; B D]
            %(6x6) for each shell, in element-local coordinates.
            % Single shell -> 6x6.  Array of N shells -> 6x6xN.
            % MaterialList: optional ads.fe.Material array to resolve
            % ply MIDs (required for PCOMP shells whose plies carry MID
            % instead of direct Material objects).
            arguments
                obj
                MaterialList = []
            end
            if length(obj) > 1
                ABD = zeros(6, 6, length(obj));
                for i = 1:length(obj)
                    ABD(:,:,i) = obj(i).getABD(MaterialList);
                end
                return
            end
            lam = obj.getLaminateData(MaterialList);
            ABD = lam.ABD;
        end

        function strains = solveStrains(obj, N, M, NV)
            %SOLVESTRAINS Per-element strain solve for one shell over one
            %or many load states.
            %
            % Inputs:
            %   N : 3xnT membrane forces  [Nx; Ny; Nxy] (per unit length)
            %   M : 3xnT bending moments  [Mx; My; Mxy] (per unit length)
            %   (Both in element-local coordinates, same convention as
            %   NASTRAN QUAD4 force output.)
            %
            % Name-Value:
            %   'Materials' : ads.fe.Material array used to resolve ply
            %                 MIDs (required for PCOMP if plies carry MID
            %                 instead of direct Material objects).
            %
            % Output (struct):
            %   eps0     : 3xnT      mid-plane strains   (element frame)
            %   kappa    : 3xnT      curvatures
            %   z        : 3xnPly    z-coords [bottom; mid; top] per ply
            %   theta    : 1xnPly    ply angles (deg)
            %   eps_xy   : 3x3xnPlyxnT element-frame ply strains
            %   eps_12   : 3x3xnPlyxnT material-frame ply strains
            %   sig_12   : 3x3xnPlyxnT material-frame ply stresses
            %   (eps_xy/eps_12/sig_12: dim1 = [exx;eyy;exy] or [e1;e2;g12],
            %    dim2 = [bot,mid,top], dim3 = ply, dim4 = time)
            arguments
                obj (1,1)
                N (3,:) double
                M (3,:) double
                NV.Materials = []
            end
            nT = size(N,2);
            if size(M,2) ~= nT
                error('ads:fe:Shell:solveStrains:DimMismatch', ...
                    'N and M must have the same number of time columns.');
            end

            lam = obj.getLaminateData(NV.Materials);
            eps_curv = lam.abd * [N; M];          % 6xnT
            eps0  = eps_curv(1:3, :);
            kappa = eps_curv(4:6, :);

            nPly = size(lam.z, 2);
            eps_xy = zeros(3, 3, nPly, nT);
            eps_12 = zeros(3, 3, nPly, nT);
            sig_12 = zeros(3, 3, nPly, nT);
            for k = 1:nPly
                Ts = lam.Tstrain(:,:,k);
                Qk = lam.Q(:,:,k);
                for r = 1:3              % 1=bot, 2=mid, 3=top
                    z_kr = lam.z(r, k);
                    e_xy = eps0 + z_kr * kappa;          % 3xnT
                    e_12 = Ts * e_xy;                    % 3xnT
                    s_12 = Qk * e_12;                    % 3xnT
                    eps_xy(:, r, k, :) = e_xy;
                    eps_12(:, r, k, :) = e_12;
                    sig_12(:, r, k, :) = s_12;
                end
            end

            strains.eps0   = eps0;
            strains.kappa  = kappa;
            strains.z      = lam.z;
            strains.theta  = lam.theta;
            strains.eps_xy = eps_xy;
            strains.eps_12 = eps_12;
            strains.sig_12 = sig_12;
        end

        % =================================================================
        %                          VISUALISATION
        % =================================================================

        function patches = plotResponse(obj, QuadForce, NV)
            %PLOTRESPONSE Colour-maps shell elements by a chosen scalar
            %derived from a QUAD4 force time history (output of
            %read_dynamic). Supports static (one time), envelope (worst
            %over time), and animate (looping) modes.
            %
            % Inputs:
            %   QuadForce : struct with fields EIDs, Nx, Ny, Nxy, Mx, My,
            %               Mxy (each nT x nQuad). Output of read_dynamic.
            %
            % Name-Value options:
            %   'Mode'        : 'static' | 'envelope' (default) | 'animate'
            %   'Quantity'    : scalar to plot. One of:
            %                   forces : 'Nx','Ny','Nxy','Mx','My','Mxy'
            %                   element-frame strain : 'eps_xx','eps_yy','gamma_xy'
            %                   material-frame strain: 'eps_1','eps_2','gamma_12'
            %                   material-frame stress: 'sig_1','sig_2','tau_12'
            %                   failure indices      : 'TsaiHill','MaxStrain','MaxStress'
            %                   default: 'MaxStrain'
            %   'TimeIndex'   : (static) time row to use. Default = peak |Z-disp|
            %                   if Displacement provided, else floor(nT/2).
            %   'PlyIndex'    : []  -> worst across all plies (default)
            %                   k   -> only ply k
            %   'ZLocation'   : 'worst' (default) | 'top' | 'mid' | 'bottom'
            %                   For 'worst', considers ply top+bottom (skips mid).
            %   'Allowables'  : struct of overrides applied per ply to
            %                   getAllowables(). e.g. struct('eXt',5e-3,'eXc',4e-3).
            %   'Materials'   : ads.fe.Material array used to resolve ply
            %                   MIDs (required for PCOMP if plies don't
            %                   carry direct Material references).
            %                   Pass NastranRefModel.FeModel.Materials.
            %   'NewFigure'   : true (default) — open a fresh figure so
            %                   only the shells render. Set false to draw
            %                   into gca on top of an existing model view.
            %                   Ignored if 'Axes' is supplied.
            %   'AeroPanels'  : optional array of aero-panel objects (e.g.
            %                   model.AeroPanels) drawn first as faint
            %                   grey-blue background for spatial context.
            %   'CLim'        : [cMin cMax] manual colour limits. Default
            %                   auto: symmetric about 0 for signed scalars,
            %                   [0,max] for failure indices.
            %   'Colormap'    : 'parula' (default), 'turbo', diverging map,
            %                   or Nx3 RGB.
            %   'Axes'        : axes handle. If supplied, draws into it
            %                   and 'NewFigure' is ignored.
            %   --- animate-only ---
            %   'Displacement': Displacement struct from read_dynamic
            %                   (.IDs, .X, .Y, .Z). If provided, mesh
            %                   deforms each frame. Optional.
            %   'TimeVec'     : nT x 1 time values for frame titles.
            %   'Stride'      : (animate) step every N-th time index.
            %   'OutputFile'  : (animate) '.mp4'|'.avi'|'.gif'. Empty = no save.
            %   'FrameRate'   : (animate) default 30.
            %   'Scale'       : deformation scale factor. Default 1.
            arguments
                obj
                QuadForce struct
                NV.Mode (1,:) char {mustBeMember(NV.Mode, {'static','envelope','animate'})} = 'envelope'
                NV.Quantity (1,:) char = 'MaxStrain'
                NV.TimeIndex double = []
                NV.PlyIndex double = []
                NV.ZLocation (1,:) char {mustBeMember(NV.ZLocation,{'top','mid','bottom','worst'})} = 'worst'
                NV.Allowables struct = struct()
                NV.Materials = []
                NV.NewFigure (1,1) logical = true
                NV.AeroPanels = []
                NV.CLim double = []
                NV.Colormap = 'parula'
                NV.Axes = []
                NV.Displacement struct = struct()
                NV.TimeVec double = []
                NV.Stride (1,1) double = 1
                NV.OutputFile (1,:) char = ''
                NV.FrameRate (1,1) double = 30
                NV.Scale (1,1) double = 1
            end

            % ---- map shell EIDs to QuadForce columns ----
            [~, qi] = ismember([obj.EID], QuadForce.EIDs);
            valid = qi > 0;
            if ~any(valid)
                warning('plotResponse:NoMatch','No shell EIDs match QuadForce.EIDs.');
                patches = gobjects(0); return
            end
            nT = size(QuadForce.Mx, 1);

            % ---- precompute laminate data + per-ply allowables ----
            lamData = cell(length(obj),1);
            allowables = cell(length(obj),1);
            for i = 1:length(obj)
                if valid(i)
                    lamData{i} = obj(i).getLaminateData(NV.Materials);
                    allowables{i} = i_perPlyAllowables(lamData{i}, NV.Allowables);
                end
            end

            % ---- branch on mode ----
            switch NV.Mode
                case 'static'
                    t_idx = NV.TimeIndex;
                    if isempty(t_idx)
                        if isfield(NV.Displacement,'Z') && ~isempty(NV.Displacement.Z)
                            [~, t_idx] = max(max(abs(NV.Displacement.Z), [], 2));
                        else
                            t_idx = max(1, floor(nT/2));
                        end
                    end
                    scalars = nan(length(obj),1);
                    for i = 1:length(obj)
                        if ~valid(i), continue; end
                        N_i = [QuadForce.Nx(t_idx, qi(i)); QuadForce.Ny(t_idx, qi(i)); QuadForce.Nxy(t_idx, qi(i))];
                        M_i = [QuadForce.Mx(t_idx, qi(i)); QuadForce.My(t_idx, qi(i)); QuadForce.Mxy(t_idx, qi(i))];
                        scalars(i) = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
                    end
                    titleStr = sprintf('%s @ t-index %d', NV.Quantity, t_idx);
                    patches = i_drawColored(obj, scalars, NV, titleStr);

                case 'envelope'
                    scalars = nan(length(obj),1);
                    for i = 1:length(obj)
                        if ~valid(i), continue; end
                        N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
                        M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
                        scalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
                    end
                    titleStr = sprintf('%s — envelope over %d time steps', NV.Quantity, nT);
                    patches = i_drawColored(obj, scalars, NV, titleStr);

                case 'animate'
                    patches = i_animateResponse(obj, QuadForce, qi, valid, lamData, allowables, NV);
            end
        end

        function results = extractResults(obj, QuadForce, NV)
            %EXTRACTRESULTS Per-element strain/stress/geometry extraction
            %for post-processing — packages everything you need to save
            %alongside dyn_data into one struct.
            %
            % Inputs:
            %   QuadForce : struct from read_dynamic (.EIDs, .Nx, .Ny,
            %               .Nxy, .Mx, .My, .Mxy as nT x nQuad).
            %
            % Name-Value:
            %   'Materials'      : ads.fe.Material array for PCOMP MID
            %                      resolution.
            %   'TimeIndices'    : indices into the time dim of QuadForce.
            %                      Default = all time steps. (Input only;
            %                      not echoed in the output struct.)
            %   'IncludePerPly'  : true to also save full per-ply
            %                      strain/stress histories per element.
            %                      Default false — only laminate-level
            %                      strain (eps0, kappa) and worst-case
            %                      failure indices kept. Per-ply data is
            %                      memory-heavy (~2 MB / element / 1000
            %                      time steps), so default off.
            %   'ABDTolerance'   : tolerance for grouping ABDs into unique
            %                      laminate groups. Default 1e-6 (relative,
            %                      passed to uniquetol).
            %
            % Output struct fields:
            %   --- geometry ---
            %   .EIDs            (nE x 1)        element IDs
            %   .Coords          (3 x 4 x nE)    undeformed corner coords
            %
            %   --- unique laminate groups (skin vs spar) ---
            %   .UniqueABD       (6 x 6 x nU)    unique ABD matrices
            %   .ABDGroup        (nE x 1)        index into UniqueABD per element
            %   .ABDGroupSize    (nU x 1)        # elements in each group
            %   .ABDGroupRepEID  (nU x 1)        first EID found in each group
            %
            %   --- time-varying laminate-level response ---
            %   .eps0            (3 x nT x nE)   mid-plane strain (element-frame)
            %   .kappa           (3 x nT x nE)   curvatures
            %
            %   --- worst-case failure indices per element per time ---
            %   .MaxStrainFI     (nT x nE)       worst across plies & bot/top
            %   .TsaiHillFI      (nT x nE)
            %   .MaxStressFI     (nT x nE)
            %
            %   --- per-ply detail (optional) ---
            %   .PerPly          (nE x 1 cell)   only if IncludePerPly=true
            %       Each cell: struct with eps_xy, eps_12, sig_12
            %       (each 3 x 3 x nPly x nT), z (3 x nPly), theta (1 x nPly).
            %
            % Example:
            %   res = NastranRefModel.FeModel.Shells.extractResults(Q, ...
            %       'Materials', mats);
            %   dyn_data(1).ShellResults = res;
            %
            %   % find critical element by max-strain failure index:
            %   [~, eEnv] = max(max(res.MaxStrainFI, [], 1));
            %   fprintf('Worst element: EID=%d, group=%d, peak FI=%.3f\n', ...
            %       res.EIDs(eEnv), res.ABDGroup(eEnv), ...
            %       max(res.MaxStrainFI(:, eEnv)));
            %
            %   % laminate groups (use A11/D11 to characterise each):
            %   for g = 1:size(res.UniqueABD,3)
            %       abdG = res.UniqueABD(:,:,g);
            %       fprintf('  group %d: %d elements, A11=%.2e, D11=%.2e, rep EID=%d\n', ...
            %           g, res.ABDGroupSize(g), abdG(1,1), abdG(4,4), ...
            %           res.ABDGroupRepEID(g));
            %   end
            arguments
                obj
                QuadForce struct
                NV.Materials = []
                NV.TimeIndices double = []
                NV.IncludePerPly (1,1) logical = false
                NV.ABDTolerance (1,1) double = 1e-6
            end

            [~, qi] = ismember([obj.EID], QuadForce.EIDs);
            valid = qi > 0;

            nT_all = size(QuadForce.Mx, 1);
            if isempty(NV.TimeIndices)
                t_idx = 1:nT_all;
            else
                t_idx = NV.TimeIndices(:)';
            end
            nT = numel(t_idx);
            nE = numel(obj);

            % --- allocate output ---
            results = struct();
            results.EIDs         = [obj.EID]';
            results.Coords       = nan(3, 4, nE);
            results.eps0         = nan(3, nT, nE);
            results.kappa        = nan(3, nT, nE);
            results.MaxStrainFI  = nan(nT, nE);
            results.TsaiHillFI   = nan(nT, nE);
            results.MaxStressFI  = nan(nT, nE);
            if NV.IncludePerPly
                results.PerPly = cell(nE, 1);
            end

            % per-element ABDs are computed but NOT stored in output;
            % we only emit the unique set at the end.
            ABD_all = zeros(6, 6, nE);

            % --- per-element loop ---
            for i = 1:nE
                sh = obj(i);

                % geometry (always extract, even for invalid shells)
                nodes = [sh.G];
                nNode = numel(nodes);
                if nNode > 0
                    pos = [nodes.GlobalPos];
                    results.Coords(:, 1:min(nNode,4), i) = pos(:, 1:min(nNode,4));
                end

                if ~valid(i), continue; end

                % laminate data
                try
                    lam = sh.getLaminateData(NV.Materials);
                catch ME
                    warning('extractResults:LaminateData', ...
                        'Shell EID=%d skipped (%s).', sh.EID, ME.message);
                    continue
                end
                ABD_all(:, :, i) = lam.ABD;

                % time-history forces -> 3 x nT each
                N_i = [QuadForce.Nx(t_idx, qi(i))'; ...
                       QuadForce.Ny(t_idx, qi(i))'; ...
                       QuadForce.Nxy(t_idx, qi(i))'];
                M_i = [QuadForce.Mx(t_idx, qi(i))'; ...
                       QuadForce.My(t_idx, qi(i))'; ...
                       QuadForce.Mxy(t_idx, qi(i))'];

                % laminate-level strain solve (vectorised over time)
                eps_curv = lam.abd * [N_i; M_i];
                eps0  = eps_curv(1:3, :);
                kappa = eps_curv(4:6, :);
                results.eps0(:, :, i)  = eps0;
                results.kappa(:, :, i) = kappa;

                % per-ply failure indices (worst across plies & bot/top)
                allowables = i_perPlyAllowables(lam, struct());
                nPly = size(lam.z, 2);
                ms_max = -inf(1, nT);
                th_max = -inf(1, nT);
                st_max = -inf(1, nT);
                if NV.IncludePerPly
                    eps_xy_full = zeros(3, 3, nPly, nT);
                    eps_12_full = zeros(3, 3, nPly, nT);
                    sig_12_full = zeros(3, 3, nPly, nT);
                end
                for k = 1:nPly
                    Ts = lam.Tstrain(:,:,k);
                    Qk = lam.Q(:,:,k);
                    al_k = allowables{k};
                    for r = 1:3   % bot, mid, top
                        z_kr = lam.z(r, k);
                        e_xy = eps0 + z_kr * kappa;     % 3 x nT
                        e_12 = Ts * e_xy;
                        s_12 = Qk * e_12;
                        if NV.IncludePerPly
                            eps_xy_full(:, r, k, :) = e_xy;
                            eps_12_full(:, r, k, :) = e_12;
                            sig_12_full(:, r, k, :) = s_12;
                        end
                        if r == 1 || r == 3   % FI from bot+top only (skip mid)
                            ms_max = max(ms_max, i_maxStrainFI(e_12, al_k));
                            th_max = max(th_max, i_tsaiHill(s_12, al_k));
                            st_max = max(st_max, i_maxStressFI(s_12, al_k));
                        end
                    end
                end
                results.MaxStrainFI(:, i) = ms_max(:);
                results.TsaiHillFI(:, i)  = th_max(:);
                results.MaxStressFI(:, i) = st_max(:);

                if NV.IncludePerPly
                    results.PerPly{i} = struct( ...
                        'eps_xy', eps_xy_full, ...
                        'eps_12', eps_12_full, ...
                        'sig_12', sig_12_full, ...
                        'z',      lam.z, ...
                        'theta',  lam.theta);
                end
            end

            % --- unique ABD groups ---
            [results.UniqueABD, results.ABDGroup, ...
             ~, ~] = ...
                i_uniqueABD(ABD_all, valid, results.EIDs, NV.ABDTolerance);
        end

    end

    methods(Access = private)
        function lam = getLaminateData(obj, MaterialList)
            %getLaminateData Precomputes per-element laminate quantities.
            % MaterialList: optional ads.fe.Material array used to resolve
            % ply MIDs to material objects (required for PCOMP if plies
            % don't carry direct Material references).
            % Returns struct with ABD, abd, z(3xnPly: bot/mid/top), theta,
            % Q (material-frame), Qbar (element-frame), Tstrain (R*T*Rinv
            % strain rotation matrix per ply), Material (per ply), t.
            arguments
                obj (1,1)
                MaterialList = []
            end
            if obj.ExportType == "PCOMP"
                layers = obj.ply.Layers;
                if isempty(layers)
                    error('ads:fe:Shell:getLaminateData:NoPlies', ...
                        'Shell EID=%d is PCOMP but has no ply layers.', obj.EID);
                end

                % Step 1: read the listed plies (bottom-up to mid-plane
                % if LAM='SYM', otherwise full laminate)
                nListed = length(layers);
                t_list     = zeros(1, nListed);
                theta_list = zeros(1, nListed);
                mats_list  = cell(1, nListed);
                for k = 1:nListed
                    pl = layers(k);
                    t_list(k)     = pl.T;
                    theta_list(k) = ads.fe.Shell.i_plyAngle(pl);
                    mats_list{k}  = ads.fe.Shell.i_resolveMaterial(pl, MaterialList);
                end

                % Step 2: apply the PCOMP LAM option.
                % NASTRAN PCOMP LAM values:
                %   ""/blank : full laminate listed -> use as-is
                %   "SYM"    : symmetric -> listed plies are bottom half,
                %              mirror about midplane to form full stack
                %   "MEM"    : membrane only -> A matrix only is used
                %   "BEND"   : bending only -> D matrix only is used
                %   "SMEAR"  : smeared membrane (A averaged through thickness)
                %   "SMCORE" : smeared core
                lam_opt = "";
                if isprop(obj.ply, 'LAM') && ~isempty(obj.ply.LAM)
                    lam_opt = upper(string(obj.ply.LAM));
                end
                switch lam_opt
                    case {"", "BLANK"}
                        t     = t_list;
                        theta = theta_list;
                        mats  = mats_list;
                    case "SYM"
                        % mirror listed plies about midplane: full stack
                        % is [listed; reverse(listed)] - works for even
                        % ply counts. For an odd-ply symmetric layup
                        % NASTRAN expects the user to specify the centre
                        % ply at half thickness, which then also mirrors;
                        % we follow the same convention.
                        t     = [t_list,     fliplr(t_list)];
                        theta = [theta_list, fliplr(theta_list)];
                        mats  = [mats_list,  fliplr(mats_list)];
                    case {"MEM","BEND","SMEAR","SMCORE"}
                        warning('ads:fe:Shell:LAM:Smeared', ...
                            ['Shell EID=%d uses LAM=%s. Standard CLPT ABD is ' ...
                             'computed; NASTRAN''s special %s behaviour ' ...
                             '(membrane-only, bending-only, smeared) is NOT ' ...
                             'replicated here. Strains/FIs may diverge from ' ...
                             'the solver output.'], obj.EID, lam_opt, lam_opt);
                        t     = t_list;
                        theta = theta_list;
                        mats  = mats_list;
                    otherwise
                        warning('ads:fe:Shell:LAM:Unknown', ...
                            'Shell EID=%d has unknown LAM=''%s''. Treating as full laminate.', ...
                            obj.EID, lam_opt);
                        t     = t_list;
                        theta = theta_list;
                        mats  = mats_list;
                end
                nPly = length(t);
            else  % PSHELL — treat as single layer
                if isempty(obj.Mat) || ~isscalar(obj.Mat)
                    error('ads:fe:Shell:getLaminateData:NoMaterial', ...
                        'PSHELL shell EID=%d has no Mat assigned.', obj.EID);
                end
                nPly = 1;
                t = obj.Thickness;
                theta = 0;
                mats = {obj.Mat};
            end

            Q = zeros(3,3,nPly);
            Qbar = zeros(3,3,nPly);
            Tstrain = zeros(3,3,nPly);
            for k = 1:nPly
                Q(:,:,k) = ads.fe.Shell.i_Q_planeStress(mats{k});
                Qbar(:,:,k) = ads.fe.Shell.i_rotateQ(Q(:,:,k), theta(k));
                Tstrain(:,:,k) = ads.fe.Shell.i_Tstrain(theta(k));
            end

            h = sum(t);
            z_bound = -h/2 + [0, cumsum(t)];   % 1 x (nPly+1)
            z = zeros(3, nPly);
            z(1,:) = z_bound(1:end-1);                          % bottom
            z(2,:) = (z_bound(1:end-1) + z_bound(2:end))/2;     % mid
            z(3,:) = z_bound(2:end);                            % top

            A = zeros(3,3); B = zeros(3,3); D = zeros(3,3);
            for k = 1:nPly
                Qb = Qbar(:,:,k);
                A = A + Qb*(z_bound(k+1)   - z_bound(k));
                B = B + Qb*(z_bound(k+1)^2 - z_bound(k)^2)/2;
                D = D + Qb*(z_bound(k+1)^3 - z_bound(k)^3)/3;
            end
            ABD = [A B; B D];

            lam.ABD = ABD;
            lam.abd = inv(ABD);
            lam.z = z;
            lam.theta = theta;
            lam.Q = Q;
            lam.Qbar = Qbar;
            lam.Tstrain = Tstrain;
            lam.Material = mats;
            lam.t = t;
        end
    end

    methods(Static)
        function obj = FromBaffStations(st,G,Mat,Thickness)
            arguments
                st baff.station.ShellStation.Shell
                G(4,1) ads.fe.Point
                Mat ads.fe.Material
                Thickness double
            end
            if st.ExportType == "PCOMP"
                PlyDef = ads.fe.PlyDefinition.FromBaffStation(st.ply);
            elseif st.ExportType == "PSHELL"
                PlyDef = ads.fe.PlyDefinition.empty;
            end
            obj = ads.fe.Shell(G,Mat,Thickness,"ExportType",st.ExportType,"ply",PlyDef);
        end
    end

    methods (Static, Access = private)
        function Q = i_Q_planeStress(mat)
            %i_Q_planeStress Plane-stress reduced stiffness for one
            %material. Handles both MAT1 (isotropic) and MAT8 (orthotropic).
            if mat.MAT == "MAT8"
                E1 = mat.E1;  E2 = mat.E2;
                nu12 = mat.NU12;  G12 = mat.G12;
                if any(isnan([E1, E2, nu12, G12]))
                    error('ads:fe:Shell:BadMat8', ...
                        'MAT8 material "%s" is missing E1/E2/NU12/G12.', mat.Name);
                end
                nu21  = E2/E1 * nu12;
                denom = 1 - nu12*nu21;
                Q11 = E1   / denom;
                Q22 = E2   / denom;
                Q12 = nu12 * E2 / denom;
                Q66 = G12;
                Q = [Q11 Q12 0;  Q12 Q22 0;  0 0 Q66];
            else  % MAT1
                E  = mat.E;
                nu = mat.nu;
                denom = 1 - nu^2;
                Q11 = E  / denom;
                Q12 = nu * E / denom;
                Q66 = E  / (2 * (1 + nu));
                Q = [Q11 Q12 0;  Q12 Q11 0;  0 0 Q66];
            end
        end

        function Qbar = i_rotateQ(Q, theta_deg)
            %i_rotateQ Rotate reduced stiffness Q from material frame
            %(1-2) to element-local frame (x-y) by ply angle theta (deg).
            Q11 = Q(1,1); Q22 = Q(2,2); Q12 = Q(1,2); Q66 = Q(3,3);
            m = cosd(theta_deg);  n = sind(theta_deg);
            m2 = m^2; n2 = n^2; m4 = m^4; n4 = n^4; mn2 = m2*n2;
            Qbar11 = Q11*m4 + 2*(Q12 + 2*Q66)*mn2 + Q22*n4;
            Qbar22 = Q11*n4 + 2*(Q12 + 2*Q66)*mn2 + Q22*m4;
            Qbar12 = (Q11 + Q22 - 4*Q66)*mn2 + Q12*(n4 + m4);
            Qbar66 = (Q11 + Q22 - 2*Q12 - 2*Q66)*mn2 + Q66*(n4 + m4);
            Qbar16 = (Q11 - Q12 - 2*Q66)*n*m^3 - (Q22 - Q12 - 2*Q66)*m*n^3;
            Qbar26 = (Q11 - Q12 - 2*Q66)*m*n^3 - (Q22 - Q12 - 2*Q66)*n*m^3;
            Qbar = [Qbar11 Qbar12 Qbar16;
                    Qbar12 Qbar22 Qbar26;
                    Qbar16 Qbar26 Qbar66];
        end

        function Tstr = i_Tstrain(theta_deg)
            %i_Tstrain Strain transformation matrix mapping element-frame
            %engineering strain [exx;eyy;gxy] to material-frame engineering
            %strain [e1;e2;g12]. Equals R*T*inv(R) where R=diag(1,1,2)
            %(Reuter) and T is the standard 2D stress rotation.
            m = cosd(theta_deg);  n = sind(theta_deg);
            % equivalent simplified form of R*T*R^-1 for engineering strain:
            Tstr = [ m^2,   n^2,   m*n;
                     n^2,   m^2,  -m*n;
                    -2*m*n, 2*m*n, m^2 - n^2];
        end

        function ang = i_plyAngle(pl)
            %i_plyAngle Robustly extract a ply angle (in degrees) from an
            %ads.fe.PlyLayer object. The class doesn't have a single
            %canonical property name across versions — some use 'Theta',
            %others 'Angle', 'Orientation', 'Orient', or lowercase
            %variants — so we probe in priority order. Add or reorder
            %candidates below if your local class uses a different name.
            candidates = {'THETA','Theta','ThetaB','Angle','theta','angle', ...
                          'Orientation','Orient','Direction','Phi'};
            p = properties(pl);
            for k = 1:numel(candidates)
                if any(strcmp(p, candidates{k}))
                    ang = pl.(candidates{k});
                    return
                end
            end
            error('ads:fe:Shell:PlyAngle', ...
                ['Could not find a ply-angle property on ads.fe.PlyLayer. ' ...
                 'Tried: %s. Available: %s. ' ...
                 'Add the correct name to the candidates list in ads.fe.Shell.i_plyAngle.'], ...
                strjoin(candidates, ', '), strjoin(p, ', '));
        end

        function mat = i_resolveMaterial(pl, MaterialList)
            %i_resolveMaterial Returns the ads.fe.Material object for a
            %given PlyLayer. Tries a direct .Material reference first
            %(some ply-layer implementations carry the object directly);
            %otherwise resolves via material ID against MaterialList.
            p = properties(pl);
            % direct object reference?
            for cand = {'Material','Mat'}
                if any(strcmp(p, cand{1}))
                    val = pl.(cand{1});
                    if isa(val, 'ads.fe.Material') && ~isempty(val)
                        mat = val;  return
                    end
                end
            end
            % ID-based resolution
            id_candidates = {'MID','MaterialID','material_id','MatID'};
            mid_val = [];
            for k = 1:numel(id_candidates)
                if any(strcmp(p, id_candidates{k}))
                    mid_val = pl.(id_candidates{k});
                    break
                end
            end
            if isempty(mid_val)
                error('ads:fe:Shell:NoPlyMaterialRef', ...
                    ['PlyLayer carries no resolvable material reference. ' ...
                     'Looked for Material/Mat objects and MID/MaterialID ids. Available: %s.'], ...
                    strjoin(p, ', '));
            end
            if isempty(MaterialList)
                error('ads:fe:Shell:NoMaterialList', ...
                    ['Ply references material id=%g but no Materials list was supplied. ' ...
                     'Pass ''Materials'' to plotResponse / solveStrains / getABD ' ...
                     '(e.g. ''Materials'', NastranRefModel.FeModel.Materials).'], ...
                    mid_val);
            end
            ids = arrayfun(@(m) m.ID, MaterialList);
            idx = find(ids == mid_val, 1);
            if isempty(idx)
                error('ads:fe:Shell:MIDNotFound', ...
                    'Ply references MID=%g but no material with that ID was found in the supplied list (have IDs: %s).', ...
                    mid_val, mat2str(ids));
            end
            mat = MaterialList(idx);
        end
    end
end


% =========================================================================
%                       LOCAL (FILE-PRIVATE) FUNCTIONS
% =========================================================================
% These are not class methods so they can't access private static members
% of ads.fe.Shell — they use only the precomputed lamData/allowables.

function al = i_perPlyAllowables(lam, overrides)
    nPly = length(lam.Material);
    al = cell(nPly, 1);
    for k = 1:nPly
        mat = lam.Material{k};
        if ismethod(mat, 'getAllowables')
            al{k} = mat.getAllowables(overrides);
        else
            % material doesn't expose getAllowables — fall back to raw fields
            al{k} = struct('Xt',mat.Xt,'Xc',mat.Xc,'Yt',mat.Yt,'Yc',mat.Yc,'S',mat.S, ...
                'eXt',NaN,'eXc',NaN,'eYt',NaN,'eYc',NaN,'eS',NaN);
        end
    end
end

function s = i_scalarOneState(N, M, lam, allowables, NV)
    %i_scalarOneState One element, one time state -> one scalar.
    q = NV.Quantity;
    % --- raw forces ---
    switch q
        case 'Nx',  s = N(1); return
        case 'Ny',  s = N(2); return
        case 'Nxy', s = N(3); return
        case 'Mx',  s = M(1); return
        case 'My',  s = M(2); return
        case 'Mxy', s = M(3); return
    end
    % --- need strain solve ---
    eps_curv = lam.abd * [N; M];
    eps0  = eps_curv(1:3);
    kappa = eps_curv(4:6);
    s = i_aggregateOverPlies(eps0, kappa, lam, allowables, NV);
end

function s = i_scalarEnvelope(N, M, lam, allowables, NV)
    %i_scalarEnvelope One element, full time history -> envelope scalar.
    %N,M are 3xnT.
    q = NV.Quantity;
    % --- raw forces (no strain solve) ---
    switch q
        case 'Nx',  vals = N(1,:);
        case 'Ny',  vals = N(2,:);
        case 'Nxy', vals = N(3,:);
        case 'Mx',  vals = M(1,:);
        case 'My',  vals = M(2,:);
        case 'Mxy', vals = M(3,:);
        otherwise
            vals = [];
    end
    if ~isempty(vals)
        if i_isUnsignedFI(q)
            s = max(vals);
        else
            [~, idx] = max(abs(vals));
            s = vals(idx);
        end
        return
    end
    % --- strain solve (vectorised over time) ---
    eps_curv = lam.abd * [N; M];           % 6 x nT
    eps0  = eps_curv(1:3, :);
    kappa = eps_curv(4:6, :);
    % aggregate ply-by-ply, taking time max within each ply, then ply max
    s_best = -Inf; abs_best = -Inf;
    if isempty(NV.PlyIndex)
        ply_range = 1:size(lam.z, 2);
    else
        ply_range = NV.PlyIndex;
    end
    z_rows = i_zRows(NV.ZLocation);
    use_max = i_isUnsignedFI(q);
    for k = ply_range
        Ts = lam.Tstrain(:,:,k);
        Qk = lam.Q(:,:,k);
        al_k = allowables{k};
        for r = z_rows
            z_kr = lam.z(r, k);
            e_xy = eps0 + z_kr * kappa;     % 3 x nT
            e_12 = Ts * e_xy;               % 3 x nT
            s_12 = Qk * e_12;               % 3 x nT
            vals = i_quantityFromState(q, e_xy, e_12, s_12, al_k);
            if use_max
                v = max(vals);
                if v > s_best, s_best = v; end
            else
                [vabs, idx] = max(abs(vals));
                if vabs > abs_best
                    abs_best = vabs;
                    s_best   = vals(idx);
                end
            end
        end
    end
    s = s_best;
end

function s = i_aggregateOverPlies(eps0, kappa, lam, allowables, NV)
    %Aggregate ply-by-ply for a single time state.
    q = NV.Quantity;
    if isempty(NV.PlyIndex)
        ply_range = 1:size(lam.z, 2);
    else
        ply_range = NV.PlyIndex;
    end
    z_rows = i_zRows(NV.ZLocation);
    use_max = i_isUnsignedFI(q);
    s_best = -Inf; abs_best = -Inf;
    for k = ply_range
        Ts = lam.Tstrain(:,:,k);
        Qk = lam.Q(:,:,k);
        al_k = allowables{k};
        for r = z_rows
            z_kr = lam.z(r, k);
            e_xy = eps0 + z_kr * kappa;
            e_12 = Ts * e_xy;
            s_12 = Qk * e_12;
            v = i_quantityFromState(q, e_xy, e_12, s_12, al_k);
            if use_max
                if v > s_best, s_best = v; end
            else
                if abs(v) > abs_best
                    abs_best = abs(v);
                    s_best   = v;
                end
            end
        end
    end
    s = s_best;
end

function vals = i_quantityFromState(q, e_xy, e_12, s_12, al)
    %Compute the named quantity from element/ply state. Supports both
    %scalar (3x1) and vectorised (3xnT) inputs; returns row vector.
    switch q
        case 'eps_xx',    vals = e_xy(1,:);
        case 'eps_yy',    vals = e_xy(2,:);
        case 'gamma_xy',  vals = e_xy(3,:);
        case 'eps_1',     vals = e_12(1,:);
        case 'eps_2',     vals = e_12(2,:);
        case 'gamma_12',  vals = e_12(3,:);
        case 'sig_1',     vals = s_12(1,:);
        case 'sig_2',     vals = s_12(2,:);
        case 'tau_12',    vals = s_12(3,:);
        case 'TsaiHill',  vals = i_tsaiHill(s_12, al);
        case 'MaxStrain', vals = i_maxStrainFI(e_12, al);
        case 'MaxStress', vals = i_maxStressFI(s_12, al);
        otherwise
            error('plotResponse:UnknownQuantity', ...
                'Unknown Quantity "%s".', q);
    end
end

function fi = i_tsaiHill(s, al)
    s11 = s(1,:); s22 = s(2,:); t12 = s(3,:);
    X = al.Xt * ones(size(s11));  X(s11 < 0) = al.Xc;
    Y = al.Yt * ones(size(s22));  Y(s22 < 0) = al.Yc;
    if isnan(al.S) || al.S == 0
        warning('TsaiHill:BadShearAllowable','Shear allowable S is NaN/0.');
        fi = nan(size(s11)); return
    end
    fi = (s11./X).^2 + (s22./Y).^2 + (t12./al.S).^2 - (s11.*s22)./X.^2;
end

function fi = i_maxStrainFI(e, al)
    e1 = e(1,:); e2 = e(2,:); g12 = e(3,:);
    fi1 = zeros(size(e1));  fi1(e1>=0) = e1(e1>=0)/al.eXt;  fi1(e1<0) = -e1(e1<0)/al.eXc;
    fi2 = zeros(size(e2));  fi2(e2>=0) = e2(e2>=0)/al.eYt;  fi2(e2<0) = -e2(e2<0)/al.eYc;
    fi3 = abs(g12) / al.eS;
    fi = max([fi1; fi2; fi3], [], 1);
end

function fi = i_maxStressFI(s, al)
    s1 = s(1,:); s2 = s(2,:); t12 = s(3,:);
    fi1 = zeros(size(s1));  fi1(s1>=0) = s1(s1>=0)/al.Xt;  fi1(s1<0) = -s1(s1<0)/al.Xc;
    fi2 = zeros(size(s2));  fi2(s2>=0) = s2(s2>=0)/al.Yt;  fi2(s2<0) = -s2(s2<0)/al.Yc;
    fi3 = abs(t12) / al.S;
    fi = max([fi1; fi2; fi3], [], 1);
end

function rows = i_zRows(loc)
    switch loc
        case 'bottom', rows = 1;
        case 'mid',    rows = 2;
        case 'top',    rows = 3;
        case 'worst',  rows = [1 3];   % bottom and top (skip mid)
    end
end

function tf = i_isUnsignedFI(q)
    tf = any(strcmp(q, {'TsaiHill','MaxStrain','MaxStress'}));
end

% -------------------------------------------------------------------------

function patches = i_drawColored(obj, scalars, NV, titleStr)
    %Draw shells coloured by per-element scalars. Returns patch handles.
    % Axes-selection priority:
    %   1. NV.Axes (if valid handle) — draw into the supplied axes
    %   2. NV.NewFigure == true       — open a fresh figure (default)
    %   3. fall back to gca           — reuse current axes
    if ~isempty(NV.Axes) && isgraphics(NV.Axes)
        hAx = NV.Axes;
    elseif isfield(NV,'NewFigure') && NV.NewFigure
        hAx = axes(figure);
    else
        hAx = gca;
    end
    hold(hAx, 'on');

    % --- optional aero-panel context (faint background, drawn first) ---
    if isfield(NV,'AeroPanels') && ~isempty(NV.AeroPanels)
        i_drawAeroBackground(hAx, NV.AeroPanels);
    end

    [cLim, isFI] = i_resolveCLim(scalars, NV);

    patches = gobjects(length(obj), 1);
    for i = 1:length(obj)
        nodes = [obj(i).G];
        if isempty(nodes) || isnan(scalars(i)), continue; end
        Xs = [nodes.GlobalPos];   % 3 x 4
        patches(i) = patch(hAx, ...
            'XData', Xs(1,:)', 'YData', Xs(2,:)', 'ZData', Xs(3,:)', ...
            'FaceColor', 'flat', 'CData', scalars(i), ...
            'EdgeColor', [0.3 0.3 0.3], ...
            'Tag', sprintf('Shell %d', obj(i).EID), 'UserData', obj(i));
    end

    clim(hAx, cLim);
    if ischar(NV.Colormap) || isstring(NV.Colormap)
        colormap(hAx, char(NV.Colormap));
    else
        colormap(hAx, NV.Colormap);
    end
    cb = colorbar(hAx);
    cb.Label.String = NV.Quantity;
    axis(hAx, 'equal');
    title(hAx, titleStr, 'Interpreter','none');
    view(hAx, 3);
    xlabel(hAx, 'x'); ylabel(hAx, 'y'); zlabel(hAx, 'z');

    % overlay a contour at FI=1 hint (text only — patches are per-element)
    if isFI && cLim(2) >= 1
        title(hAx, sprintf('%s   (FI=1 is the structural limit)', titleStr), 'Interpreter','none');
    end
end

function i_drawAeroBackground(hAx, aero)
    %Draw aero panels as faint background context. Tries .drawElement()
    %first (most ads/matran element classes implement it); falls back to a
    %quad-patch from per-panel corners if it can find them. Silently
    %ignores failures so a bad background never kills the main plot.
    try
        h = aero.drawElement();
    catch
        h = [];
    end
    if isempty(h)
        warning('plotResponse:AeroPanels','Could not draw AeroPanels (no drawElement output).');
        return
    end
    for j = 1:numel(h)
        if ~isgraphics(h(j)), continue; end
        try
            h(j).Parent     = hAx;
            h(j).FaceColor  = [0.78 0.84 0.94];
            h(j).FaceAlpha  = 0.10;
            h(j).EdgeColor  = [0.55 0.60 0.70];
            h(j).EdgeAlpha  = 0.35;
            h(j).LineWidth  = 0.5;
            h(j).PickableParts = 'none';
            h(j).Tag = "AeroPanelBackground";
        catch
            % best-effort styling
        end
    end
end

function [cLim, isFI] = i_resolveCLim(scalars, NV)
    isFI = i_isUnsignedFI(NV.Quantity);
    if ~isempty(NV.CLim)
        cLim = NV.CLim;  return
    end
    v = scalars(~isnan(scalars));
    if isempty(v)
        cLim = [-1, 1]; return
    end
    if isFI
        cLim = [0, max(v)];
        if cLim(2) == 0, cLim(2) = 1; end
    else
        vmax = max(abs(v));
        if vmax == 0, vmax = 1; end
        cLim = [-vmax, vmax];
    end
end

% -------------------------------------------------------------------------

function patches = i_animateResponse(obj, QuadForce, qi, valid, lamData, allowables, NV)
    %Animate plotResponse. Loops over time, updates patch CData (and
    %vertex coords if Displacement provided), optionally writes to file.

    nT = size(QuadForce.Mx, 1);
    t_indices = 1:NV.Stride:nT;
    nFrames = numel(t_indices);
    if nFrames < 2
        warning('plotResponse:animate:NoFrames','Stride/range yields <2 frames; falling back to envelope.');
        patches = i_animateFallback(obj, QuadForce, qi, valid, lamData, allowables, NV);
        return
    end

    % ---- precompute envelope scalars to fix CLim consistently ----
    if isempty(NV.CLim)
        envScalars = nan(length(obj),1);
        for i = 1:length(obj)
            if ~valid(i), continue; end
            N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
            M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
            envScalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
        end
        cLim = i_resolveCLim(envScalars, NV);
    else
        cLim = NV.CLim;
    end

    % ---- initial draw (first time index) ----
    NV0 = NV;  NV0.CLim = cLim;
    t0 = t_indices(1);
    scalars0 = nan(length(obj),1);
    for i = 1:length(obj)
        if ~valid(i), continue; end
        N_i = [QuadForce.Nx(t0,qi(i)); QuadForce.Ny(t0,qi(i)); QuadForce.Nxy(t0,qi(i))];
        M_i = [QuadForce.Mx(t0,qi(i)); QuadForce.My(t0,qi(i)); QuadForce.Mxy(t0,qi(i))];
        scalars0(i) = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
    end
    patches = i_drawColored(obj, scalars0, NV0, sprintf('%s — animating', NV.Quantity));

    % undeformed vertex coordinates (3 x 4 x nElem) + node id mapping
    [undefXYZ, di, hasDisp] = i_setupDeformation(obj, NV.Displacement);
    if hasDisp
        Dx = NV.Displacement.X;   % nT x nNodes
        Dy = NV.Displacement.Y;
        Dz = NV.Displacement.Z;
    end

    % time vector for titles
    if isempty(NV.TimeVec) || numel(NV.TimeVec) ~= nT
        tVec = (1:nT)';
        tLabel = @(k) sprintf('frame %d/%d', k, nFrames);
    else
        tVec = NV.TimeVec;
        tLabel = @(k) sprintf('t = %.4g s   (frame %d/%d)', tVec(t_indices(k)), k, nFrames);
    end

    hAx = ancestor(patches(find(isgraphics(patches),1,'first')), 'axes');
    hFig = ancestor(hAx, 'figure');
    title_h = get(hAx, 'Title');

    % output writer
    writer = []; isGif = false;
    outFile = NV.OutputFile;
    if ~isempty(outFile)
        [~,~,ext] = fileparts(outFile);
        switch lower(ext)
            case '.gif',  isGif = true;
            case {'.mp4','.m4v'}
                writer = VideoWriter(outFile,'MPEG-4');
                writer.FrameRate = NV.FrameRate;
                open(writer);
            case '.avi'
                writer = VideoWriter(outFile,'Motion JPEG AVI');
                writer.FrameRate = NV.FrameRate;
                open(writer);
            otherwise
                error('plotResponse:animate:BadExt','Unrecognised output extension "%s".', ext);
        end
    end
    cleanupObj = onCleanup(@() i_finalizeWriter(writer)); %#ok<NASGU>

    % ---- main loop ----
    for k = 1:nFrames
        t_idx = t_indices(k);
        % update colors + (optionally) vertex positions
        for i = 1:length(obj)
            if ~valid(i) || ~isgraphics(patches(i)), continue; end
            N_i = [QuadForce.Nx(t_idx,qi(i)); QuadForce.Ny(t_idx,qi(i)); QuadForce.Nxy(t_idx,qi(i))];
            M_i = [QuadForce.Mx(t_idx,qi(i)); QuadForce.My(t_idx,qi(i)); QuadForce.Mxy(t_idx,qi(i))];
            s_i = i_scalarOneState(N_i, M_i, lamData{i}, allowables{i}, NV);
            patches(i).CData = s_i;
            if hasDisp
                X = squeeze(undefXYZ(:, :, i));    % 3 x 4
                valid_n = di(i,:) > 0;
                if any(valid_n)
                    X(1, valid_n) = X(1, valid_n) + NV.Scale * Dx(t_idx, di(i, valid_n));
                    X(2, valid_n) = X(2, valid_n) + NV.Scale * Dy(t_idx, di(i, valid_n));
                    X(3, valid_n) = X(3, valid_n) + NV.Scale * Dz(t_idx, di(i, valid_n));
                end
                patches(i).XData = X(1,:)';
                patches(i).YData = X(2,:)';
                patches(i).ZData = X(3,:)';
            end
        end
        clim(hAx, cLim);
        title_h.String = sprintf('%s   %s', NV.Quantity, tLabel(k));
        drawnow;

        if ~isempty(writer) || isGif
            frame = getframe(hFig);
            if ~isempty(writer)
                writeVideo(writer, frame);
            else
                [A,map] = rgb2ind(frame.cdata, 256);
                if k == 1
                    imwrite(A,map,outFile,'gif','LoopCount',Inf,'DelayTime',1/NV.FrameRate);
                else
                    imwrite(A,map,outFile,'gif','WriteMode','append','DelayTime',1/NV.FrameRate);
                end
            end
        end
    end
end

function [undefXYZ, di, hasDisp] = i_setupDeformation(obj, Displacement)
    %Build (3 x 4 x nElem) array of undeformed node coords and a (nElem x 4)
    %matrix of column indices into Displacement.IDs for each shell's nodes.
    nE = length(obj);
    undefXYZ = zeros(3, 4, nE);
    di = zeros(nE, 4);
    hasDisp = isfield(Displacement,'IDs') && ~isempty(Displacement.IDs) ...
              && isfield(Displacement,'X');
    for i = 1:nE
        nodes = [obj(i).G];
        if isempty(nodes), continue; end
        Xs = [nodes.GlobalPos];   % 3 x 4
        % pad to 4 columns if a tri-shell or partial
        if size(Xs,2) < 4
            Xs = [Xs, repmat(Xs(:,end), 1, 4-size(Xs,2))];
        end
        undefXYZ(:,:,i) = Xs(:, 1:4);
        if hasDisp
            ids = arrayfun(@(p) p.ID, nodes(:));
            ids = ids(:)';
            if numel(ids) < 4, ids = [ids, repmat(ids(end), 1, 4-numel(ids))]; end
            [~, idx] = ismember(ids, Displacement.IDs);
            di(i, :) = idx(1:4);
        end
    end
end

function i_finalizeWriter(writer)
    if ~isempty(writer)
        try, close(writer); catch, end
    end
end

function patches = i_animateFallback(obj, QuadForce, qi, valid, lamData, allowables, NV)
    %Fallback: too few frames -> just do envelope plot.
    scalars = nan(length(obj),1);
    for i = 1:length(obj)
        if ~valid(i), continue; end
        N_i = [QuadForce.Nx(:,qi(i))'; QuadForce.Ny(:,qi(i))'; QuadForce.Nxy(:,qi(i))'];
        M_i = [QuadForce.Mx(:,qi(i))'; QuadForce.My(:,qi(i))'; QuadForce.Mxy(:,qi(i))'];
        scalars(i) = i_scalarEnvelope(N_i, M_i, lamData{i}, allowables{i}, NV);
    end
    patches = i_drawColored(obj, scalars, NV, sprintf('%s — envelope (animate fallback)', NV.Quantity));
end

function [uniqueABD, group, groupSize, repEID] = i_uniqueABD(ABD, validMask, EIDs, tol)
    %i_uniqueABD Reduce a stack of per-element 6x6 ABD matrices to its
    %unique entries (within tolerance) and emit an element->group index
    %map. Invalid elements get group = NaN.
    %
    % Tolerance is applied as absolute (|a-b| <= tol*DataScale) where
    % DataScale = global max|ABD|. This is essential: ABD matrices mix
    % A-block magnitudes (often 1e7..1e9) with B-coupling terms (which
    % are floating-point zero ~ 1e-14 for symmetric laminates). The
    % default relative tolerance in uniquetol would treat tiny B-noise
    % as significant differences and split otherwise-identical laminates
    % into separate groups.
    nE = size(ABD, 3);
    group = nan(nE, 1);

    validIdx = find(validMask(:));
    if isempty(validIdx)
        uniqueABD = zeros(6, 6, 0);
        groupSize = zeros(0, 1);
        repEID    = zeros(0, 1);
        return
    end

    flat = reshape(ABD(:, :, validIdx), 36, []).';   % nValid x 36

    ds = max(abs(flat(:)));
    if ds == 0, ds = 1; end
    [~, ia, ic] = uniquetol(flat, tol, 'ByRows', true, 'DataScale', ds);

    uniqueABD = ABD(:, :, validIdx(ia));
    group(validIdx) = ic;

    nU = numel(ia);
    groupSize = accumarray(ic, 1, [nU, 1]);
    repEID    = EIDs(validIdx(ia));
end