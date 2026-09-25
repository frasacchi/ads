% function fe = wing2fe(obj,baffOpts)
% arguments
%     obj
%     baffOpts ads.baff.BaffOpts = ads.baff.BaffOpts();
% end
% 
% if isa(obj.Stations,'baff.station.Beam') || isa(obj.Stations,'baff.station.SuperBeam')
%     [fe,Etas] = beam2fe(obj,baffOpts,PointName=obj.Name);
%     SplineType = 4;
% elseif isa(obj.Stations,'baff.station.ShellStation.ShellStation')
%     [fe,Etas] = shell2fe(obj,baffOpts,PointName=obj.Name);
%     SplineType = 1;
% end
% 
% if ~baffOpts.GenerateAeroPanels
%     return
% end
% if isfield(obj.Meta,'ads') && isfield(obj.Meta.ads,'GenerateAeroPanels') && ~obj.Meta.ads.GenerateAeroPanels
%     return
% end
% 
% CS = fe.CoordSys(1);
% 
% % Capture structural attachment node indices before any LE/TE nodes are added
% idxi = find([fe.Points.Note] == "AttachmentNode");
% 
% % CS = fe.CoordSys(1);
% isWingtipLogic = isWingtip(obj);
% 
% %% Build (eta, structural node) pairs covering the aero span, then generate LE/TE nodes
% 
% aeroStart = obj.AeroStations.Eta(1);
% aeroEnd   = obj.AeroStations.Eta(end);
% idx = find(Etas >= aeroStart & Etas <= aeroEnd);
% 
% etas_proc   = Etas(idx);
% points_proc = fe.Points(idxi(idx));
% isWingtip_array = zeros(numel(etas_proc),1);
% isWingtip_array(end) = isWingtipLogic;
% 
% % Prepend a boundary station if the structural grid starts too far from the aero root
% if abs(etas_proc(1) - aeroStart) > 0.01
%     [~,ii]      = min(abs(Etas - aeroStart));
%     etas_proc   = [aeroStart,            etas_proc  ];
%     points_proc = [fe.Points(idxi(ii)),  points_proc];
% end
% 
% % Append a boundary station if the structural grid ends too far from the aero tip
% if abs(etas_proc(end) - aeroEnd) > 0.01
%     [~,ii]      = min(abs(Etas - aeroEnd));
%     etas_proc   = [etas_proc,   aeroEnd           ];
%     points_proc = [points_proc, fe.Points(idxi(ii))];
% end
% 
% for i = 1:numel(etas_proc)
%     debug(i) = addLeTe(obj,fe,etas_proc(i),points_proc(i),isWingtip_array(i),CS);
% end
% 
% %% debug
% is_nan_mask = arrayfun(@(m) any(isnan(m.Xi_le)), debug);
% debug_clean = debug(~is_nan_mask);
% 
% all_Xi_le = [debug_clean.Xi_le];
% all_Xi_te = [debug_clean.Xi_te];
% Xi = [debug_clean.X_ba];
% 
% N = size(all_Xi_le, 2);
% combined_coords = zeros(3, 3*N);
% combined_coords(:, 1:3:end) = all_Xi_le;
% combined_coords(:, 2:3:end) = all_Xi_te;
% combined_coords(:, 3:3:end) = Xi;
% 
% figure;
% hold on
% % plot(all_Xi_le(2, :), all_Xi_le(1, :), 'r*')
% % plot(all_Xi_te(2, :), all_Xi_te(1, :), 'b*')
% % plot(Xi(2, :), Xi(1, :), 'm*')
% 
% plot(combined_coords(2, :),combined_coords(1, :),'k-*')
% 
% %% Add aero surfaces (include control surface eta breaks)
% etas = unique([obj.AeroStations.Eta, reshape([obj.ControlSurfaces.Etas],1,[])]);
% st = obj.AeroStations.interpolate(etas);
% 
% idxA = find([fe.Points.Note] == "AttachmentNode");
% for i = 1:(st.N-1)
%     sts = st.GetIndex(i:(i+1));
%     Xs  = [obj.GetPos(st.Eta(i)), obj.GetPos(st.Eta(i+1))];
%     fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,sts.BeamLoc,sts.Chord, ...
%         StructuralPoints=fe.Points,CoordSys=CS,Twists=sts.Twist);
%     vecs = [st.GetPos(st.Eta(i),1)-st.GetPos(st.Eta(i),0), ...
%             st.GetPos(st.Eta(i+1),1)-st.GetPos(st.Eta(i+1),0)];
%     fe.AeroSurfaces(i).ChordVecs    = vecs ./ repmat(vecnorm(vecs),3,1);
%     fe.AeroSurfaces(i).CrossEta     = 0.5;
%     fe.AeroSurfaces(i).LiftCurveSlope = st.LiftCurveSlope(i);
%     fe.AeroSurfaces(i).SplineType   = SplineType;
%     if SplineType == 1
%         fe.AeroSurfaces(i).StructuralPoints = fe.Points(idxA);
%     end
% end
% 
% %% Add secondary mass from aerodynamic stations
% stMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.SecondaryMassStation+1));
% for i = 1:(stMass.N-1)
%     stEtas = stMass.Eta(i:(i+1));
%     stEta  = mean(stEtas);
%     sti    = stMass.interpolate(stEta);
%     dL     = (stEtas(2)-stEtas(1)) * obj.EtaLength;
%     if sti.HasMass
%         X_m = obj.AeroStations.GetPos(stEta,sti.MassLoc) + obj.GetPos(stEta);
%         fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,midx] = min(abs(Etas - stEta));
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
%         fe.Masses(end+1) = ads.fe.Mass(sti.LinearDensity.*dL,fe.Points(end), ...
%             Ixx=sti.LinearInertia(1,1)*dL, Iyy=sti.LinearInertia(2,2)*dL, Izz=sti.LinearInertia(3,3)*dL, ...
%             Ixy=sti.LinearInertia(1,2)*dL, Ixz=sti.LinearInertia(1,3)*dL, Iyz=sti.LinearInertia(2,3)*dL);
%     end
% end
% 
% %% Add aero added mass
% if baffOpts.IncludeAeroAddedMass
%     stAddedMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.AddedMassStations+1));
%     for i = 1:(stAddedMass.N-1)
%         cs_chord = stAddedMass.Chord(i:(i+1));
%         stEtas   = stAddedMass.Eta(i:(i+1));
%         stEta    = mean(stEtas);
%         sti      = stAddedMass.interpolate(stEta);
%         dL       = (stEtas(2)-stEtas(1)) * obj.EtaLength;
%         b        = mean(cs_chord) / 2;
%         X_m = obj.AeroStations.GetPos(stEta,0.5) + obj.GetPos(stEta);
%         fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,midx] = min(abs(Etas - stEta));
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
%         rho = baffOpts.AirDensity;
%         M   = diag([0,0,1]) * (0.5*rho*b^2*pi) * dL;
%         I   = abs(diag(sti.EtaDir)) * rho*pi*b^4/8 * dL / norm(sti.EtaDir);
%         fe.Inertias(end+1) = ads.fe.Inertia(blkdiag(M,I),fe.Points(end));
%     end
% end
% 
% %% Add control surfaces
% cs_idx = ads.fe.Point.empty;
% for i = 1:length(obj.ControlSurfaces)
%     if obj.ControlSurfaces(i).pChord(1) ~= obj.ControlSurfaces(i).pChord(2)
%         error('For MSC Nastran the control surface must be a constant percentage of the chord')
%     end
%     fe.ControlSurfaces(i) = ads.fe.ControlSurface(obj.ControlSurfaces(i).Name);
%     HingeEta = (1 - obj.ControlSurfaces.pChord(1));
% 
%     if baffOpts.SeperateSplineForControlSurfaces
%         X1   = obj.GetPos(obj.ControlSurfaces(i).Etas(1));
%         X2   = obj.GetPos(obj.ControlSurfaces(i).Etas(2));
%         X_h1 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),HingeEta);
%         X_h2 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(end),HingeEta);
% 
%         fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,cidx] = min((Etas - obj.ControlSurfaces(i).Etas(2)).^2);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end));
% 
%         fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=obj.A*(obj.Offset+X1+X_h1),A=obj.A);
%         for ii = 1:2
%             fe.Points(end+1) = ads.fe.Point(zeros(3,1), ...
%                 InputCoordSys=fe.CoordSys(end),OutputCoordSys=fe.CoordSys(end));
%         end
%         fe.Points(end-1).isAttachmentPoint = false;
%         fe.Points(end).isAnchorPoint       = false;
% 
%         [~,cidx] = min((Etas - obj.ControlSurfaces(i).Etas(1)).^2);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end-1));
% 
%         fe.Hinges(end+1) = ads.fe.Hinge(fe.Points((end-1):end),fe.CoordSys(end),1e-3,0,isLocked=false);
% 
%         Ail_point = fe.Points(end);
%         fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%         add_p = 2;
% 
%         if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(1)))
%             fe.Points(end+1) = ads.fe.Point( ...
%                 X1+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),1), ...
%                 InputCoordSys=CS,isAnchor=false,isAttachment=false);
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%             add_p = add_p + 1;
%         end
%         if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(2)))
%             fe.Points(end+1) = ads.fe.Point( ...
%                 X2+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(2),1), ...
%                 InputCoordSys=CS,isAnchor=false,isAttachment=false);
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%             add_p = add_p + 1;
%         end
% 
%         cidx_range = find(Etas>=obj.ControlSurfaces(i).Etas(1) & Etas<=obj.ControlSurfaces(i).Etas(2));
%         Ail_points = fe.Points(numel(Etas)+cidx_range*2);
%         cs_idx(end+1:end+numel(Ail_points)) = Ail_points;
%         fe.ControlSurfaces(i).StructuralPoints = [Ail_points; fe.Points((end-add_p+1):end)];
%         idx_bars = ~ismember([fe.RigidBars.Point2],Ail_points);
%         fe.RigidBars = fe.RigidBars(idx_bars);
%         for ii = 1:length(Ail_points)
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,Ail_points(ii));
%         end
%         fe.Masses(end+1) = ads.fe.Mass(0,Ail_point,Ixx=1e-6);
%     end
% 
%     idx_cs = 0;
%     for j = 1:(st.N-1)
%         if st.Eta(j) >= obj.ControlSurfaces(i).Etas(1) && st.Eta(j) < obj.ControlSurfaces(i).Etas(2)
%             fe.AeroSurfaces(j).ControlSurface = fe.ControlSurfaces(i);
%             fe.AeroSurfaces(j).HingeEta       = (1-obj.ControlSurfaces.pChord(1));
%             idx_cs = idx_cs + 1;
%             fe.ControlSurfaces(i).AeroSurfaces(idx_cs) = fe.AeroSurfaces(j);
%         end
%     end
%     if ~isempty(obj.ControlSurfaces(i).LinkedSurface)
%         fe.ControlSurfaces(i).LinkedSurface    = obj.ControlSurfaces(i).LinkedSurface.Name;
%         fe.ControlSurfaces(i).LinkedCoefficent = obj.ControlSurfaces(i).LinkedCoefficent;
%     end
% end
% 
% if ~isempty(cs_idx)
%     for i = 1:length(fe.AeroSurfaces)
%         s_idx = ~ismember(fe.AeroSurfaces(i).StructuralPoints,Ail_points);
%         fe.AeroSurfaces(i).StructuralPoints = fe.AeroSurfaces(i).StructuralPoints(s_idx);
%     end
% end
% 
% end
% 
% % -------------------------------------------------------------------------
% 
% function flag = isWingtip(obj)
%     flag = true;
%     for c = 1:length(obj.Children)
%         if isa(obj.Children(c),'baff.Wing')
%             flag = false;
%             return
%         end
%         flag = isWingtip(obj.Children(c));
%     end
% end
% 
% % function debug = addLeTe(obj,fe,Eta,Node,isWingtip)
% % 
% %     [X,Dir] = obj.GetPos(Eta);
% %     chordDir = cross(Dir, cross(Dir, [0,1,0]))';
% % 
% %     X_le = obj.AeroStations.GetPos(Eta,0);
% %     X_te = obj.AeroStations.GetPos(Eta,1);
% % 
% %     if chordDir(2) > 0
% %         chordDir = -chordDir;
% %     end
% % 
% %     Etai = norm(Dir(2:3)/norm(Dir)) * norm(X_te) / obj.EtaLength;
% %     Xi_te = X + abs(Dir(1) / norm(Dir)) * norm(X_te)*chordDir/norm(chordDir);
% %     Xi_le = X - abs(Dir(1) / norm(Dir)) * norm(X_le)*chordDir/norm(chordDir);
% % 
% %     % if Xi_te(2)>Xi_le(2)
% %     %     Xi_te = X-(Dir(1) / norm(Dir)) * norm(X_te)*chordDir/norm(chordDir);
% %     %     Xi_le = X+(Dir(1) / norm(Dir)) * norm(X_le)*chordDir/norm(chordDir);
% %     % end
% % 
% %     if Eta < Etai || (Eta > (1-Etai) && ~isWingtip)
% %         debug.Xi_le = nan;
% %         debug.Xi_te = nan;
% %         debug.X_ba = X;
% %         return
% %     end
% % 
% %     if Eta == 1 && isWingtip
% %         Xi_te = X+norm(X_te)*[0,-1,0]';
% %         Xi_le = X-norm(X_le)*[0,-1,0]';
% %     end
% % 
% %     % %$ DEBUG ---- $%
% %     % Xi_le = X+X_le;
% %     % Xi_te = X+X_te;
% %     % Xi_te = X+norm(X_te)*[0,-1,0]';
% %     % Xi_le = X-norm(X_le)*[0,-1,0]';
% % 
% %     CS = Node.InputCoordSys;
% %     fe.Points(end+1) = ads.fe.Point(Xi_le,InputCoordSys=CS,isAnchor=false,isAttachment=false);
% %     fe.Points(end).Tag = "AttachmentNode"; % - TO CHECK
% %     fe.Points(end).Name = obj.Name + "_LE";
% %     fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
% % 
% %     fe.Points(end+1) = ads.fe.Point(Xi_te,InputCoordSys=CS,isAnchor=false,isAttachment=false);
% %     fe.Points(end).Tag = "AttachmentNode"; % - TO CHECK
% %     fe.Points(end).Name = obj.Name + "_TE";
% %     fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
% % 
% %     debug.Xi_le = Xi_le;
% %     debug.Xi_te = Xi_te;
% %     debug.X_ba = X;
% % end
% 
% % function debug = addLeTe(obj, fe, Eta, Node, isWingtip)
% %     [X, Dir] = obj.GetPos(Eta);
% %     Dir_unit = Dir / norm(Dir);
% % 
% %     % Dir_unit = [1,0,0]';
% % 
% %     X_le0 = obj.AeroStations.GetPos(Eta, 0);
% %     X_te0 = obj.AeroStations.GetPos(Eta, 1);
% % 
% %     X_le = obj.AeroStations.GetOffsetPos(Eta, 0, Dir_unit,obj.EtaLength);
% %     X_te = obj.AeroStations.GetOffsetPos(Eta, 1, Dir_unit,obj.EtaLength);
% % 
% %     % Xi_le = X + X_le - dot(X_le, Dir_unit) * Dir_unit;
% %     % Xi_te = X + X_te - dot(X_te, Dir_unit) * Dir_unit;
% % 
% %     Etai = norm(Dir(2:3)/norm(Dir)) * norm(X_te) / obj.EtaLength;
% %     if Eta < Etai || (Eta > (1-Etai) && ~isWingtip)
% %         debug.Xi_le = nan; debug.Xi_te = nan; debug.X_ba = X;
% %         return
% %     end
% % 
% %     % if Eta == 1 && isWingtip
% %     %     Xi_te = X + norm(X_te)*[0,-1,0]';
% %     %     Xi_le = X - norm(X_le)*[0,-1,0]';
% %     % end
% % 
% %     Xi_te = X + X_te;
% %     Xi_le = X + X_le;
% % 
% %     CS = Node.InputCoordSys;
% %     fe.Points(end+1) = ads.fe.Point(Xi_le, InputCoordSys=CS, isAnchor=false, isAttachment=false);
% %     fe.Points(end).Tag = "AttachmentNode";
% %     fe.Points(end).Name = obj.Name + "_LE";
% %     fe.RigidBars(end+1) = ads.fe.RigidBar(Node, fe.Points(end));
% % 
% %     fe.Points(end+1) = ads.fe.Point(Xi_te, InputCoordSys=CS, isAnchor=false, isAttachment=false);
% %     fe.Points(end).Tag = "AttachmentNode";
% %     fe.Points(end).Name = obj.Name + "_TE";
% %     fe.RigidBars(end+1) = ads.fe.RigidBar(Node, fe.Points(end));
% % 
% %     debug.Xi_le = Xi_le; debug.Xi_te = Xi_te; debug.X_ba = X;
% % end
% 
% function [debug,res] = addLeTe(obj, fe, Eta, Node, isWingtip, CS)
%     res.LE = ads.fe.Point.empty;
%     res.TE = ads.fe.Point.empty;
% 
%     % 1. Beam station position
%     [X, Dir] = obj.GetPos(Eta);
% 
%     % 2. Query station LE and TE offsets directly matching the AeroSurfaces
%     X_le = obj.AeroStations.GetPos(Eta, 0);
%     X_te = obj.AeroStations.GetPos(Eta, 1);
% 
%     % 3. Boundary guard
%     Etai = norm(Dir(2:3) / norm(Dir)) * norm(X_te) / obj.EtaLength;
%     if Eta < Etai || (Eta > (1 - Etai) && ~isWingtip)
%         return
%     end
% 
%     % 4. Absolute coordinates
%     Xi_le = X + X_le;
%     Xi_te = X + X_te;
% 
%     % 5. Create FE Attachment Points & Rigid Bars
%     fe.Points(end+1) = ads.fe.Point(Xi_le, InputCoordSys=CS, isAnchor=false, isAttachment=true);
%     fe.Points(end).Tag  = "AttachmentNode";
%     fe.Points(end).Note = "AttachmentNode";
%     fe.Points(end).Name = obj.Name + "_LE";
%     fe.RigidBars(end+1) = ads.fe.RigidBar(Node, fe.Points(end));
%     res.LE = fe.Points(end);
% 
%     fe.Points(end+1) = ads.fe.Point(Xi_te, InputCoordSys=CS, isAnchor=false, isAttachment=true);
%     fe.Points(end).Tag  = "AttachmentNode";
%     fe.Points(end).Note = "AttachmentNode";
%     fe.Points(end).Name = obj.Name + "_TE";
%     fe.RigidBars(end+1) = ads.fe.RigidBar(Node, fe.Points(end));
%     res.TE = fe.Points(end);
% 
%     debug.Xi_le = Xi_le; debug.Xi_te = Xi_te; debug.X_ba = X;
% end


% function fe = wing2fe(obj,baffOpts)
% %WING2FE  Build FE + aero model of a baff.Wing.
% %
% % Aero panels   : streamwise cuts (unchanged, built from AeroStations.GetPos).
% % LE/TE nodes   : placed where the plane NORMAL TO THE BEAM through each
% %                 structural node cuts the streamwise panel outline, so the
% %                 rigid bars are swept (perpendicular to the beam) and the
% %                 LE/TE nodes lie exactly on the panel edges.
% %
% % Closed form of the same thing (straight beam, linear taper, eta along beam):
% %   p     = beamLoc - pChord                      (LE: p>0, TE: p<0)
% %   C*    = C0 / (1 - p*C_R*(rho-1)*sin(Lambda)/L)   chord at the hit station
% %   D     = p * C* * cos(Lambda)                  signed bar length
% %   dEta  = p * C* * sin(Lambda) / L              spanwise shift of the hit
% % (Lambda > 0 = aft sweep.) The streamwise segment p*C* is the HYPOTENUSE,
% % because the right angle is at the node -> cos multiplies, sin (not tan).
% % The code below uses the plane cut, which reduces to this exactly but also
% % handles kinks, varying beamLoc, twist and the root/tip edges.
% 
% arguments
%     obj
%     baffOpts ads.baff.BaffOpts = ads.baff.BaffOpts();
% end
% 
% doDebugPlot = false;   % set true to plot outline + swept bars
% 
% if isa(obj.Stations,'baff.station.Beam') || isa(obj.Stations,'baff.station.SuperBeam')
%     [fe,Etas] = beam2fe(obj,baffOpts,PointName=obj.Name);
%     SplineType = 4;
% elseif isa(obj.Stations,'baff.station.ShellStation.ShellStation')
%     [fe,Etas] = shell2fe(obj,baffOpts,PointName=obj.Name);
%     SplineType = 1;
% else
%     error('wing2fe:UnsupportedStation','Unsupported station type: %s',class(obj.Stations));
% end
% 
% if ~baffOpts.GenerateAeroPanels
%     return
% end
% if isfield(obj.Meta,'ads') && isfield(obj.Meta.ads,'GenerateAeroPanels') && ~obj.Meta.ads.GenerateAeroPanels
%     return
% end
% 
% % Wing frame. obj.GetPos and obj.AeroStations.GetPos are both expressed in it,
% % so every new point uses InputCoordSys = CS (same as the mass points below).
% CS = fe.CoordSys(1);
% 
% % Structural attachment nodes (one per Etas entry), captured BEFORE LE/TE nodes exist
% idxi = find([fe.Points.Note] == "AttachmentNode");
% isWingtipLogic = isWingtip(obj);
% 
% %% Swept LE/TE attachment nodes
% aeroStart = obj.AeroStations.Eta(1);
% aeroEnd   = obj.AeroStations.Eta(end);
% 
% % Streamwise panel outline (identical corners to the AeroSurfaces below)
% outline = buildOutline(obj);
% 
% idx = find(Etas >= aeroStart & Etas <= aeroEnd);
% etas_proc   = Etas(idx);
% points_proc = fe.Points(idxi(idx));
% 
% % Boundary stations if the structural grid does not reach the aero root / tip
% if abs(etas_proc(1) - aeroStart) > 0.01
%     [~,ii] = min(abs(Etas - aeroStart));
%     etas_proc   = [aeroStart,           etas_proc  ];
%     points_proc = [fe.Points(idxi(ii)), points_proc];
% end
% if abs(etas_proc(end) - aeroEnd) > 0.01
%     [~,ii] = min(abs(Etas - aeroEnd));
%     etas_proc   = [etas_proc,   aeroEnd            ];
%     points_proc = [points_proc, fe.Points(idxi(ii))];
% end
% 
% LE_nodes = ads.fe.Point.empty;  TE_nodes = ads.fe.Point.empty;
% etaLE = zeros(1,0);             etaTE = zeros(1,0);
% dbg = zeros(3,0);
% for i = 1:numel(etas_proc)
%     % The geometric tip-edge check replaces the old per-station isWingtip array
%     res = addLeTe(obj,fe,etas_proc(i),points_proc(i),outline,isWingtipLogic,CS);
%     if res.ok
%         LE_nodes(end+1) = res.LE;     %#ok<AGROW>
%         TE_nodes(end+1) = res.TE;     %#ok<AGROW>
%         etaLE(end+1)    = res.etaLE;  %#ok<AGROW>
%         etaTE(end+1)    = res.etaTE;  %#ok<AGROW>
%         dbg(:,end+1:end+3) = [res.Xle, res.X0, res.Xte]; %#ok<AGROW>
%     end
% end
% 
% if doDebugPlot
%     figure; hold on; axis equal
%     P = [outline.Ple, fliplr(outline.Pte), outline.Ple(:,1)];
%     plot(P(2,:),P(1,:),'-','Color',[0.2 0.35 0.45],'LineWidth',1.5)       % streamwise outline
%     for k = 1:numel(outline.eta)                                            % streamwise cuts
%         plot([outline.Ple(2,k) outline.Pte(2,k)],[outline.Ple(1,k) outline.Pte(1,k)],'Color',[0.6 0.6 0.6])
%     end
%     plot(dbg(2,:),dbg(1,:),'m-')                                            % LE-node-TE polylines
%     plot(dbg(2,1:3:end),dbg(1,1:3:end),'ro','MarkerFaceColor','r')
%     plot(dbg(2,3:3:end),dbg(1,3:3:end),'bo','MarkerFaceColor','b')
%     plot(dbg(2,2:3:end),dbg(1,2:3:end),'ko','MarkerFaceColor','k')
%     xlabel('local y (chordwise)'); ylabel('local x (beam)')
% end
% 
% %% Aero surfaces (streamwise, unchanged; include control surface eta breaks)
% etas = unique([obj.AeroStations.Eta, reshape([obj.ControlSurfaces.Etas],1,[])]);
% st = obj.AeroStations.interpolate(etas);
% 
% idxA = find([fe.Points.Note] == "AttachmentNode");   % now includes LE/TE nodes
% for i = 1:(st.N-1)
%     sts = st.GetIndex(i:(i+1));
%     Xs  = [obj.GetPos(st.Eta(i)), obj.GetPos(st.Eta(i+1))];
%     fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,sts.BeamLoc,sts.Chord, ...
%         StructuralPoints=fe.Points,CoordSys=CS,Twists=sts.Twist);
%     vecs = [st.GetPos(st.Eta(i),1)-st.GetPos(st.Eta(i),0), ...
%             st.GetPos(st.Eta(i+1),1)-st.GetPos(st.Eta(i+1),0)];
%     fe.AeroSurfaces(i).ChordVecs      = vecs ./ repmat(vecnorm(vecs),3,1);
%     fe.AeroSurfaces(i).CrossEta       = 0.5;
%     fe.AeroSurfaces(i).LiftCurveSlope = st.LiftCurveSlope(i);
%     fe.AeroSurfaces(i).SplineType     = SplineType;
%     if SplineType == 1
%         fe.AeroSurfaces(i).StructuralPoints = fe.Points(idxA);
%     end
% end
% 
% %% Secondary mass from aerodynamic stations
% stMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.SecondaryMassStation+1));
% for i = 1:(stMass.N-1)
%     stEtas = stMass.Eta(i:(i+1));
%     stEta  = mean(stEtas);
%     sti    = stMass.interpolate(stEta);
%     dL     = (stEtas(2)-stEtas(1)) * obj.EtaLength;
%     if sti.HasMass
%         X_m = obj.AeroStations.GetPos(stEta,sti.MassLoc) + obj.GetPos(stEta);
%         fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,midx] = min(abs(Etas - stEta));
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
%         fe.Masses(end+1) = ads.fe.Mass(sti.LinearDensity.*dL,fe.Points(end), ...
%             Ixx=sti.LinearInertia(1,1)*dL, Iyy=sti.LinearInertia(2,2)*dL, Izz=sti.LinearInertia(3,3)*dL, ...
%             Ixy=sti.LinearInertia(1,2)*dL, Ixz=sti.LinearInertia(1,3)*dL, Iyz=sti.LinearInertia(2,3)*dL);
%     end
% end
% 
% %% Aero added mass
% if baffOpts.IncludeAeroAddedMass
%     stAddedMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.AddedMassStations+1));
%     for i = 1:(stAddedMass.N-1)
%         cs_chord = stAddedMass.Chord(i:(i+1));
%         stEtas   = stAddedMass.Eta(i:(i+1));
%         stEta    = mean(stEtas);
%         sti      = stAddedMass.interpolate(stEta);
%         dL       = (stEtas(2)-stEtas(1)) * obj.EtaLength;
%         b        = mean(cs_chord) / 2;
%         X_m = obj.AeroStations.GetPos(stEta,0.5) + obj.GetPos(stEta);
%         fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,midx] = min(abs(Etas - stEta));
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
%         rho = baffOpts.AirDensity;
%         M   = diag([0,0,1]) * (0.5*rho*b^2*pi) * dL;
%         I   = abs(diag(sti.EtaDir)) * rho*pi*b^4/8 * dL / norm(sti.EtaDir);
%         fe.Inertias(end+1) = ads.fe.Inertia(blkdiag(M,I),fe.Points(end));
%     end
% end
% 
% %% Control surfaces
% cs_idx = ads.fe.Point.empty;
% for i = 1:length(obj.ControlSurfaces)
%     csi = obj.ControlSurfaces(i);
%     if csi.pChord(1) ~= csi.pChord(2)
%         error('For MSC Nastran the control surface must be a constant percentage of the chord')
%     end
%     fe.ControlSurfaces(i) = ads.fe.ControlSurface(csi.Name);
%     HingeEta = 1 - csi.pChord(1);                      % was obj.ControlSurfaces.pChord (no index)
% 
%     if baffOpts.SeperateSplineForControlSurfaces
%         X1   = obj.GetPos(csi.Etas(1));
%         X2   = obj.GetPos(csi.Etas(2));
%         X_h1 = obj.AeroStations.GetPos(csi.Etas(1),HingeEta);
%         X_h2 = obj.AeroStations.GetPos(csi.Etas(end),HingeEta);
% 
%         fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         [~,cidx] = min((Etas - csi.Etas(2)).^2);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end));
% 
%         fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=obj.A*(obj.Offset+X1+X_h1),A=obj.A);
%         for ii = 1:2
%             fe.Points(end+1) = ads.fe.Point(zeros(3,1), ...
%                 InputCoordSys=fe.CoordSys(end),OutputCoordSys=fe.CoordSys(end));
%         end
%         fe.Points(end-1).isAttachmentPoint = false;
%         fe.Points(end).isAnchorPoint       = false;
% 
%         [~,cidx] = min((Etas - csi.Etas(1)).^2);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end-1));
% 
%         fe.Hinges(end+1) = ads.fe.Hinge(fe.Points((end-1):end),fe.CoordSys(end),1e-3,0,isLocked=false);
% 
%         Ail_point = fe.Points(end);
%         fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
%         fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%         add_p = 2;
% 
%         if ~any(ismember(Etas,csi.Etas(1)))
%             fe.Points(end+1) = ads.fe.Point(X1+obj.AeroStations.GetPos(csi.Etas(1),1), ...
%                 InputCoordSys=CS,isAnchor=false,isAttachment=false);
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%             add_p = add_p + 1;
%         end
%         if ~any(ismember(Etas,csi.Etas(2)))
%             fe.Points(end+1) = ads.fe.Point(X2+obj.AeroStations.GetPos(csi.Etas(2),1), ...
%                 InputCoordSys=CS,isAnchor=false,isAttachment=false);
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
%             add_p = add_p + 1;
%         end
% 
%         % TE nodes inside the control-surface span, selected by the eta where
%         % the swept bar actually hits the TE (replaces numel(Etas)+cidx_range*2,
%         % which breaks as soon as a station is skipped or the bars are swept)
%         Ail_points = TE_nodes(etaTE >= csi.Etas(1) & etaTE <= csi.Etas(2));
%         extra      = fe.Points((end-add_p+1):end);
%         if iscolumn(extra), Ail_points = Ail_points(:); else, Ail_points = Ail_points(:).'; end
%         cs_idx = [cs_idx(:); Ail_points(:)]; %#ok<AGROW>
% 
%         fe.ControlSurfaces(i).StructuralPoints = [Ail_points; extra];
%         idx_bars = ~ismember([fe.RigidBars.Point2],Ail_points);
%         fe.RigidBars = fe.RigidBars(idx_bars);
%         for ii = 1:numel(Ail_points)
%             fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,Ail_points(ii));
%         end
%         fe.Masses(end+1) = ads.fe.Mass(0,Ail_point,Ixx=1e-6);
%     end
% 
%     idx_cs = 0;
%     for j = 1:(st.N-1)
%         if st.Eta(j) >= csi.Etas(1) && st.Eta(j) < csi.Etas(2)
%             fe.AeroSurfaces(j).ControlSurface = fe.ControlSurfaces(i);
%             fe.AeroSurfaces(j).HingeEta       = HingeEta;
%             idx_cs = idx_cs + 1;
%             fe.ControlSurfaces(i).AeroSurfaces(idx_cs) = fe.AeroSurfaces(j);
%         end
%     end
%     if ~isempty(csi.LinkedSurface)
%         fe.ControlSurfaces(i).LinkedSurface    = csi.LinkedSurface.Name;
%         fe.ControlSurfaces(i).LinkedCoefficent = csi.LinkedCoefficent;
%     end
% end
% 
% % Remove ALL control-surface TE nodes from the main-wing splines (was only the last CS)
% if ~isempty(cs_idx)
%     for i = 1:length(fe.AeroSurfaces)
%         s_idx = ~ismember(fe.AeroSurfaces(i).StructuralPoints,cs_idx);
%         fe.AeroSurfaces(i).StructuralPoints = fe.AeroSurfaces(i).StructuralPoints(s_idx);
%     end
% end
% 
% end
% 
% % =========================================================================
% 
% function flag = isWingtip(obj)
%     flag = true;
%     for c = 1:length(obj.Children)
%         if isa(obj.Children(c),'baff.Wing')
%             flag = false;
%             return
%         end
%         flag = isWingtip(obj.Children(c));
%     end
% end
% 
% % -------------------------------------------------------------------------
% 
% function ol = buildOutline(obj)
% %BUILDOUTLINE  Closed streamwise panel outline in the wing frame.
% %  Edge types: 1 = LE, 2 = TE, 3 = tip chord, 4 = root chord.
%     eta = obj.AeroStations.Eta(:).';
%     n   = numel(eta);
%     Ple = zeros(3,n);  Pte = zeros(3,n);
%     for k = 1:n
%         Xk = obj.GetPos(eta(k));
%         Ple(:,k) = Xk(:) + reshape(obj.AeroStations.GetPos(eta(k),0),3,1);
%         Pte(:,k) = Xk(:) + reshape(obj.AeroStations.GetPos(eta(k),1),3,1);
%     end
%     ol.A    = [Ple(:,1:n-1), Pte(:,1:n-1), Ple(:,n), Ple(:,1)];
%     ol.B    = [Ple(:,2:n),   Pte(:,2:n),   Pte(:,n), Pte(:,1)];
%     ol.etaA = [eta(1:n-1),   eta(1:n-1),   eta(n),   eta(1)];
%     ol.etaB = [eta(2:n),     eta(2:n),     eta(n),   eta(1)];
%     ol.type = [ones(1,n-1),  2*ones(1,n-1), 3,       4];
%     ol.Ple = Ple;  ol.Pte = Pte;  ol.eta = eta;
% end
% 
% % -------------------------------------------------------------------------
% 
% function res = addLeTe(obj,fe,Eta,Node,outline,isWingtip,CS)
% %ADDLETE  LE/TE attachment nodes on the beam-normal plane through the node.
%     res.ok = false;
% 
%     [X0,Dir] = obj.GetPos(Eta);
%     X0 = X0(:);
%     e  = Dir(:) / norm(Dir);                                   % rib-plane normal = beam tangent
% 
%     s  = obj.AeroStations.GetPos(Eta,0) - obj.AeroStations.GetPos(Eta,1);
%     s  = s(:) / norm(s);                                       % streamwise, pointing to the LE
% 
%     [hLE,okLE] = cutOutline(outline,X0,e,s,+1,isWingtip);
%     [hTE,okTE] = cutOutline(outline,X0,e,s,-1,isWingtip);
%     if ~(okLE && okTE)
%         return                                                 % bar would leave through root (or non-tip) chord
%     end
% 
%     fe.Points(end+1) = ads.fe.Point(hLE.X,InputCoordSys=CS,isAnchor=false,isAttachment=true);
%     fe.Points(end).Tag  = "AttachmentNode";
%     fe.Points(end).Note = "AttachmentNode";
%     fe.Points(end).Name = obj.Name + "_LE";
%     fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
%     res.LE = fe.Points(end);
% 
%     fe.Points(end+1) = ads.fe.Point(hTE.X,InputCoordSys=CS,isAnchor=false,isAttachment=true);
%     fe.Points(end).Tag  = "AttachmentNode";
%     fe.Points(end).Note = "AttachmentNode";
%     fe.Points(end).Name = obj.Name + "_TE";
%     fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
%     res.TE = fe.Points(end);
% 
%     res.etaLE = hLE.eta;  res.etaTE = hTE.eta;
%     res.X0 = X0;  res.Xle = hLE.X;  res.Xte = hTE.X;
%     res.ok = true;
% end
% 
% % -------------------------------------------------------------------------
% 
% function [hit,ok] = cutOutline(ol,X0,e,s,side,isWingtip)
% %CUTOUTLINE  Intersect plane {x : e.(x-X0)=0} with the outline edges and
% %  return the nearest hit on the requested side (+1 = LE side, -1 = TE side).
%     hit = [];  ok = false;
%     scale = max(vecnorm(ol.B - ol.A));
%     tol   = 1e-10 * max(1,scale);
% 
%     dA = e.' * (ol.A - X0);
%     dB = e.' * (ol.B - X0);
%     crosses = (dA .* dB <= 0) & (abs(dA - dB) > tol);
% 
%     t = zeros(size(dA));
%     t(crosses) = dA(crosses) ./ (dA(crosses) - dB(crosses));
%     H = ol.A + t .* (ol.B - ol.A);
% 
%     sd   = side * (s.' * (H - X0));
%     cand = find(crosses & sd > tol);
%     if isempty(cand)
%         return
%     end
% 
%     dist = vecnorm(H(:,cand) - X0);
%     dist = dist + (ol.type(cand) >= 3) * 1e-9 * max(dist);    % at a shared corner prefer the LE/TE edge
%     [~,j] = min(dist);
%     k = cand(j);
% 
%     if ol.type(k) == 4 || (ol.type(k) == 3 && ~isWingtip)
%         return
%     end
% 
%     hit.X    = H(:,k);
%     hit.eta  = ol.etaA(k) + t(k) * (ol.etaB(k) - ol.etaA(k));
%     hit.type = ol.type(k);
%     ok = true;
% end

function fe = wing2fe(obj,baffOpts)
%WING2FE  Build FE + aero model of a baff.Wing.
%
% Aero panels   : streamwise cuts (unchanged, built from AeroStations.GetPos).
% LE/TE nodes   : placed where the plane NORMAL TO THE BEAM through each
%                 structural node cuts the streamwise panel outline, so the
%                 rigid bars are swept (perpendicular to the beam) and the
%                 LE/TE nodes lie exactly on the panel edges.
%
% Closed form of the same thing (straight beam, linear taper, eta along beam):
%   p     = beamLoc - pChord                      (LE: p>0, TE: p<0)
%   C*    = C0 / (1 - p*C_R*(rho-1)*sin(Lambda)/L)   chord at the hit station
%   D     = p * C* * cos(Lambda)                  signed bar length
%   dEta  = p * C* * sin(Lambda) / L              spanwise shift of the hit
% (Lambda > 0 = aft sweep.) The streamwise segment p*C* is the HYPOTENUSE,
% because the right angle is at the node -> cos multiplies, sin (not tan).
% The code below uses the plane cut, which reduces to this exactly but also
% handles kinks, varying beamLoc, twist and the root/tip edges.

arguments
    obj
    baffOpts ads.baff.BaffOpts = ads.baff.BaffOpts();
end

doDebugPlot = false;   % set true to plot outline + swept bars

if isa(obj.Stations,'baff.station.Beam') || isa(obj.Stations,'baff.station.SuperBeam')
    [fe,Etas] = beam2fe(obj,baffOpts,PointName=obj.Name);
    SplineType = 4;
elseif isa(obj.Stations,'baff.station.ShellStation.ShellStation')
    [fe,Etas] = shell2fe(obj,baffOpts,PointName=obj.Name);
    SplineType = 1;
else
    error('wing2fe:UnsupportedStation','Unsupported station type: %s',class(obj.Stations));
end

if ~baffOpts.GenerateAeroPanels
    return
end
if isfield(obj.Meta,'ads') && isfield(obj.Meta.ads,'GenerateAeroPanels') && ~obj.Meta.ads.GenerateAeroPanels
    return
end

% Wing frame. obj.GetPos and obj.AeroStations.GetPos are both expressed in it,
% so every new point uses InputCoordSys = CS (same as the mass points below).
CS = fe.CoordSys(1);

% Structural attachment nodes (one per Etas entry), captured BEFORE LE/TE nodes exist
idxi = find([fe.Points.Note] == "AttachmentNode");
isWingtipLogic = isWingtip(obj);

%% Swept LE/TE attachment nodes
aeroStart = obj.AeroStations.Eta(1);
aeroEnd   = obj.AeroStations.Eta(end);

% Streamwise panel outline (identical corners to the AeroSurfaces below)
outline = buildOutline(obj);

% Rib hubs: every RibStride-th structural node in the aero span, always
% keeping the first/last node and the nodes nearest the control-surface
% edges. The old prepend/append of boundary stations is gone: it re-used an
% existing node, so it only produced duplicate bars on that node.
ribStride = getOpt(baffOpts,'RibStride',1);
keepEtas  = reshape([obj.ControlSurfaces.Etas],1,[]);
[etas_proc,points_proc] = selectHubs(Etas,fe.Points(idxi),aeroStart,aeroEnd,ribStride,keepEtas);

edgeMode = string(getOpt(baffOpts,'LeTeEdgeMode',"drop"));
LE_nodes = ads.fe.Point.empty;  TE_nodes = ads.fe.Point.empty;
etaLE = zeros(1,0);             etaTE = zeros(1,0);
dbg = zeros(3,0);
for i = 1:numel(etas_proc)
    % The geometric tip-edge check replaces the old per-station isWingtip array
    res = addLeTe(obj,fe,etas_proc(i),points_proc(i),outline,isWingtipLogic,CS,edgeMode);
    if res.ok
        LE_nodes(end+1) = res.LE;     %#ok<AGROW>
        TE_nodes(end+1) = res.TE;     %#ok<AGROW>
        etaLE(end+1)    = res.etaLE;  %#ok<AGROW>
        etaTE(end+1)    = res.etaTE;  %#ok<AGROW>
        dbg(:,end+1:end+3) = [res.Xle, res.X0, res.Xte]; %#ok<AGROW>
    end
end

% Streamwise end ribs: LE/TE spline nodes exactly on the first/last aero
% station, tied to the nearest hub node, so the end panels of every
% component have chordwise spline support (swept bars cannot reach them).
dbgEnd = zeros(3,0);
if getOpt(baffOpts,'AddEndRibs',false)
    existing = [dbg(:,1:3:end), dbg(:,3:3:end)];
    for eEnd = [aeroStart, aeroEnd]
        [~,ih] = min(abs(etas_proc - eEnd));
        Xb = obj.GetPos(eEnd);  Xb = Xb(:);
        Xle = Xb + reshape(obj.AeroStations.GetPos(eEnd,0),3,1);
        Xte = Xb + reshape(obj.AeroStations.GetPos(eEnd,1),3,1);
        for P = [Xle, Xte]
            if ~isempty(existing) && min(vecnorm(existing - P)) < 1e-6
                continue
            end
            fe.Points(end+1) = ads.fe.Point(P,InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.Points(end).Tag  = "AttachmentNode";
            fe.Points(end).Note = "AttachmentNode";
            fe.Points(end).Name = obj.Name + "_EndRib";
            fe.RigidBars(end+1) = ads.fe.RigidBar(points_proc(ih),fe.Points(end));
            dbgEnd(:,end+1) = P; %#ok<AGROW>
        end
    end
end

if doDebugPlot
    figure; hold on; axis equal
    P = [outline.Ple, fliplr(outline.Pte), outline.Ple(:,1)];
    plot(P(2,:),P(1,:),'-','Color',[0.2 0.35 0.45],'LineWidth',1.5)       % streamwise outline
    for k = 1:numel(outline.eta)                                            % streamwise cuts
        plot([outline.Ple(2,k) outline.Pte(2,k)],[outline.Ple(1,k) outline.Pte(1,k)],'Color',[0.6 0.6 0.6])
    end
    plot(dbg(2,:),dbg(1,:),'m-')                                            % LE-node-TE polylines
    plot(dbg(2,1:3:end),dbg(1,1:3:end),'ro','MarkerFaceColor','r')
    plot(dbg(2,3:3:end),dbg(1,3:3:end),'bo','MarkerFaceColor','b')
    plot(dbg(2,2:3:end),dbg(1,2:3:end),'ko','MarkerFaceColor','k')
    if ~isempty(dbgEnd)
        plot(dbgEnd(2,:),dbgEnd(1,:),'gs','MarkerFaceColor','g')         % end-rib nodes
    end
    xlabel('local y (chordwise)'); ylabel('local x (beam)')
end

%% Aero surfaces (streamwise, unchanged; include control surface eta breaks)
etas = unique([obj.AeroStations.Eta, reshape([obj.ControlSurfaces.Etas],1,[])]);
st = obj.AeroStations.interpolate(etas);

idxA = find([fe.Points.Note] == "AttachmentNode");   % now includes LE/TE nodes
for i = 1:(st.N-1)
    sts = st.GetIndex(i:(i+1));
    Xs  = [obj.GetPos(st.Eta(i)), obj.GetPos(st.Eta(i+1))];
    fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,sts.BeamLoc,sts.Chord, ...
        StructuralPoints=fe.Points,CoordSys=CS,Twists=sts.Twist);
    vecs = [st.GetPos(st.Eta(i),1)-st.GetPos(st.Eta(i),0), ...
            st.GetPos(st.Eta(i+1),1)-st.GetPos(st.Eta(i+1),0)];
    fe.AeroSurfaces(i).ChordVecs      = vecs ./ repmat(vecnorm(vecs),3,1);
    fe.AeroSurfaces(i).CrossEta       = 0.5;
    fe.AeroSurfaces(i).LiftCurveSlope = st.LiftCurveSlope(i);
    fe.AeroSurfaces(i).SplineType     = SplineType;
    if SplineType == 1
        fe.AeroSurfaces(i).StructuralPoints = fe.Points(idxA);
    end
end

%% Secondary mass + aero added mass, lumped onto beam hub nodes
% Each hub owns the tributary strip between the midpoints to its
% neighbours (first/last strips extend to the aero root/tip), so the total
% mass is conserved whatever the stride. Each strip is integrated with
% sub-samples and lumped EXACTLY (mass, first and second moments):
%   MassOnBeamNode = false -> one point at the strip CG + ONE bar to the hub
%                             beam node (per mass type)
%   MassOnBeamNode = true  -> one 6x6 ads.fe.Inertia directly on the beam
%                             node, NO rigid bars at all
massStride = getOpt(baffOpts,'MassStride',1);
massOnNode = getOpt(baffOpts,'MassOnBeamNode',false);
rho        = baffOpts.AirDensity;
spanAero   = aeroEnd - aeroStart;

[mEtas,mNodes] = selectHubs(Etas,fe.Points(idxi),aeroStart,aeroEnd,massStride,[]);
bnd = [aeroStart, (mEtas(1:end-1)+mEtas(2:end))/2, aeroEnd];

for j = 1:numel(mEtas)
    e1 = bnd(j);  e2 = bnd(j+1);
    if e2 <= e1, continue, end
    frac = (e2-e1)/spanAero;

    nS = max(2, ceil(baffOpts.SecondaryMassStation*frac));
    [Ms,cS,hasS] = lumpStrips(obj,e1,e2,nS,"secondary",rho);

    hasA = false;
    if baffOpts.IncludeAeroAddedMass
        nA = max(2, ceil(baffOpts.AddedMassStations*frac));
        [Ma,cA,hasA] = lumpStrips(obj,e1,e2,nA,"added",rho);
    end

    if massOnNode
        % Everything referred to the beam node itself. The 6x6 is in the wing
        % frame (CS): the hub node's OutputCoordSys must be CS (or rotate M6).
        Xn = obj.GetPos(mEtas(j));  Xn = Xn(:);
        M6 = zeros(6);
        if hasS, M6 = M6 + shiftMass(Ms, cS - Xn); end
        if hasA, M6 = M6 + shiftMass(Ma, cA - Xn); end
        if any(M6(:))
            fe.Inertias(end+1) = ads.fe.Inertia(M6,mNodes(j));
        end
        continue
    end

    if hasS
        fe.Points(end+1) = ads.fe.Point(cS,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(mNodes(j),fe.Points(end));
        I = Ms(4:6,4:6);                                   % about the CG
        fe.Masses(end+1) = ads.fe.Mass(Ms(1,1),fe.Points(end), ...
            Ixx=I(1,1), Iyy=I(2,2), Izz=I(3,3), Ixy=I(1,2), Ixz=I(1,3), Iyz=I(2,3));
    end
    if hasA
        fe.Points(end+1) = ads.fe.Point(cA,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(mNodes(j),fe.Points(end));
        fe.Inertias(end+1) = ads.fe.Inertia(Ma,fe.Points(end));
    end
end

%% Control surfaces
cs_idx = ads.fe.Point.empty;
for i = 1:length(obj.ControlSurfaces)
    csi = obj.ControlSurfaces(i);
    if csi.pChord(1) ~= csi.pChord(2)
        error('For MSC Nastran the control surface must be a constant percentage of the chord')
    end
    fe.ControlSurfaces(i) = ads.fe.ControlSurface(csi.Name);
    HingeEta = 1 - csi.pChord(1);                      % was obj.ControlSurfaces.pChord (no index)

    if baffOpts.SeperateSplineForControlSurfaces
        X1   = obj.GetPos(csi.Etas(1));
        X2   = obj.GetPos(csi.Etas(2));
        X_h1 = obj.AeroStations.GetPos(csi.Etas(1),HingeEta);
        X_h2 = obj.AeroStations.GetPos(csi.Etas(end),HingeEta);

        fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        [~,cidx] = min((Etas - csi.Etas(2)).^2);
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end));

        fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=obj.A*(obj.Offset+X1+X_h1),A=obj.A);
        for ii = 1:2
            fe.Points(end+1) = ads.fe.Point(zeros(3,1), ...
                InputCoordSys=fe.CoordSys(end),OutputCoordSys=fe.CoordSys(end));
        end
        fe.Points(end-1).isAttachmentPoint = false;
        fe.Points(end).isAnchorPoint       = false;

        [~,cidx] = min((Etas - csi.Etas(1)).^2);
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end-1));

        fe.Hinges(end+1) = ads.fe.Hinge(fe.Points((end-1):end),fe.CoordSys(end),1e-3,0,isLocked=false);

        Ail_point = fe.Points(end);
        fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
        add_p = 2;

        if ~any(ismember(Etas,csi.Etas(1)))
            fe.Points(end+1) = ads.fe.Point(X1+obj.AeroStations.GetPos(csi.Etas(1),1), ...
                InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
            add_p = add_p + 1;
        end
        if ~any(ismember(Etas,csi.Etas(2)))
            fe.Points(end+1) = ads.fe.Point(X2+obj.AeroStations.GetPos(csi.Etas(2),1), ...
                InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
            add_p = add_p + 1;
        end

        % TE nodes inside the control-surface span, selected by the eta where
        % the swept bar actually hits the TE (replaces numel(Etas)+cidx_range*2,
        % which breaks as soon as a station is skipped or the bars are swept)
        Ail_points = TE_nodes(etaTE >= csi.Etas(1) & etaTE <= csi.Etas(2));
        if numel(Ail_points) < 2
            warning('wing2fe:FewCSNodes', ...
                'Control surface %s has %d TE node(s); reduce RibStride.',csi.Name,numel(Ail_points));
        end
        extra      = fe.Points((end-add_p+1):end);
        if iscolumn(extra), Ail_points = Ail_points(:); else, Ail_points = Ail_points(:).'; end
        cs_idx = [cs_idx(:); Ail_points(:)];

        fe.ControlSurfaces(i).StructuralPoints = [Ail_points; extra];
        idx_bars = ~ismember([fe.RigidBars.Point2],Ail_points);
        fe.RigidBars = fe.RigidBars(idx_bars);
        for ii = 1:numel(Ail_points)
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,Ail_points(ii));
        end
        fe.Masses(end+1) = ads.fe.Mass(0,Ail_point,Ixx=1e-6);
    end

    idx_cs = 0;
    for j = 1:(st.N-1)
        if st.Eta(j) >= csi.Etas(1) && st.Eta(j) < csi.Etas(2)
            fe.AeroSurfaces(j).ControlSurface = fe.ControlSurfaces(i);
            fe.AeroSurfaces(j).HingeEta       = HingeEta;
            idx_cs = idx_cs + 1;
            fe.ControlSurfaces(i).AeroSurfaces(idx_cs) = fe.AeroSurfaces(j);
        end
    end
    if ~isempty(csi.LinkedSurface)
        fe.ControlSurfaces(i).LinkedSurface    = csi.LinkedSurface.Name;
        fe.ControlSurfaces(i).LinkedCoefficent = csi.LinkedCoefficent;
    end
end

% Remove ALL control-surface TE nodes from the main-wing splines (was only the last CS)
if ~isempty(cs_idx)
    for i = 1:length(fe.AeroSurfaces)
        s_idx = ~ismember(fe.AeroSurfaces(i).StructuralPoints,cs_idx);
        fe.AeroSurfaces(i).StructuralPoints = fe.AeroSurfaces(i).StructuralPoints(s_idx);
    end
end

end

% =========================================================================

function flag = isWingtip(obj)
    flag = true;
    for c = 1:length(obj.Children)
        if isa(obj.Children(c),'baff.Wing')
            flag = false;
            return
        end
        flag = isWingtip(obj.Children(c));
    end
end

% -------------------------------------------------------------------------

function ol = buildOutline(obj)
%BUILDOUTLINE  Closed streamwise panel outline in the wing frame.
%  Edge types: 1 = LE, 2 = TE, 3 = tip chord, 4 = root chord.
    eta = obj.AeroStations.Eta(:).';
    n   = numel(eta);
    Ple = zeros(3,n);  Pte = zeros(3,n);
    for k = 1:n
        Xk = obj.GetPos(eta(k));
        Ple(:,k) = Xk(:) + reshape(obj.AeroStations.GetPos(eta(k),0),3,1);
        Pte(:,k) = Xk(:) + reshape(obj.AeroStations.GetPos(eta(k),1),3,1);
    end
    ol.A    = [Ple(:,1:n-1), Pte(:,1:n-1), Ple(:,n), Ple(:,1)];
    ol.B    = [Ple(:,2:n),   Pte(:,2:n),   Pte(:,n), Pte(:,1)];
    ol.etaA = [eta(1:n-1),   eta(1:n-1),   eta(n),   eta(1)];
    ol.etaB = [eta(2:n),     eta(2:n),     eta(n),   eta(1)];
    ol.type = [ones(1,n-1),  2*ones(1,n-1), 3,       4];
    ol.Ple = Ple;  ol.Pte = Pte;  ol.eta = eta;
end

% -------------------------------------------------------------------------

function res = addLeTe(obj,fe,Eta,Node,outline,isWingtip,CS,edgeMode)
%ADDLETE  LE/TE attachment nodes on the beam-normal plane through the node.
    if nargin < 8, edgeMode = "drop"; end
    res.ok = false;

    [X0,Dir] = obj.GetPos(Eta);
    X0 = X0(:);
    e  = Dir(:) / norm(Dir);                                   % rib-plane normal = beam tangent

    s  = obj.AeroStations.GetPos(Eta,0) - obj.AeroStations.GetPos(Eta,1);
    s  = s(:) / norm(s);                                       % streamwise, pointing to the LE

    [hLE,okLE] = cutOutline(outline,X0,e,s,+1,isWingtip,edgeMode);
    [hTE,okTE] = cutOutline(outline,X0,e,s,-1,isWingtip,edgeMode);
    if ~(okLE && okTE)
        return                                                 % bar would leave through root (or non-tip) chord
    end

    fe.Points(end+1) = ads.fe.Point(hLE.X,InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.Points(end).Tag  = "AttachmentNode";
    fe.Points(end).Note = "AttachmentNode";
    fe.Points(end).Name = obj.Name + "_LE";
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
    res.LE = fe.Points(end);

    fe.Points(end+1) = ads.fe.Point(hTE.X,InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.Points(end).Tag  = "AttachmentNode";
    fe.Points(end).Note = "AttachmentNode";
    fe.Points(end).Name = obj.Name + "_TE";
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
    res.TE = fe.Points(end);

    res.etaLE = hLE.eta;  res.etaTE = hTE.eta;
    res.X0 = X0;  res.Xle = hLE.X;  res.Xte = hTE.X;
    res.ok = true;
end

% -------------------------------------------------------------------------

function [hit,ok] = cutOutline(ol,X0,e,s,side,isWingtip,edgeMode)
%CUTOUTLINE  Intersect plane {x : e.(x-X0)=0} with the outline edges and
%  return the nearest hit on the requested side (+1 = LE side, -1 = TE side).
%  edgeMode "drop": reject hits on the root chord / non-tip tip chord (legacy)
%  edgeMode "clip": keep them - the hit is still on the rigid rib plane of the node
    if nargin < 7, edgeMode = "drop"; end
    hit = [];  ok = false;
    scale = max(vecnorm(ol.B - ol.A));
    tol   = 1e-10 * max(1,scale);

    dA = e.' * (ol.A - X0);
    dB = e.' * (ol.B - X0);
    crosses = (dA .* dB <= 0) & (abs(dA - dB) > tol);

    t = zeros(size(dA));
    t(crosses) = dA(crosses) ./ (dA(crosses) - dB(crosses));
    H = ol.A + t .* (ol.B - ol.A);

    sd   = side * (s.' * (H - X0));
    cand = find(crosses & sd > tol);
    if isempty(cand)
        return
    end

    dist = vecnorm(H(:,cand) - X0);
    dist = dist + (ol.type(cand) >= 3) * 1e-9 * max(dist);    % at a shared corner prefer the LE/TE edge
    [~,j] = min(dist);
    k = cand(j);

    if edgeMode ~= "clip" && (ol.type(k) == 4 || (ol.type(k) == 3 && ~isWingtip))
        return
    end

    hit.X    = H(:,k);
    hit.eta  = ol.etaA(k) + t(k) * (ol.etaB(k) - ol.etaA(k));
    hit.type = ol.type(k);
    ok = true;
end

% -------------------------------------------------------------------------

function [hubEtas,hubNodes] = selectHubs(Etas,nodes,etaLo,etaHi,stride,keepEtas)
%SELECTHUBS  Subset of structural nodes inside [etaLo, etaHi].
    Etas = Etas(:).';  nodes = nodes(:).';
    tol  = 1e-9;
    in = find(Etas >= etaLo - tol & Etas <= etaHi + tol);
    if isempty(in)
        [~,in] = min(abs(Etas - (etaLo+etaHi)/2));
    end
    keep = false(size(in));
    keep(1:max(1,round(stride)):end) = true;
    keep([1 end]) = true;
    for k = 1:numel(keepEtas)
        [~,jj] = min(abs(Etas(in) - keepEtas(k)));
        keep(jj) = true;
    end
    sel = in(keep);
    [hubEtas,ia] = unique(Etas(sel));          % sorted, no duplicate etas
    hubNodes = nodes(sel(ia));
end

% -------------------------------------------------------------------------

function [Mc,c,has] = lumpStrips(obj,e1,e2,nSub,kind,rho)
%LUMPSTRIPS  Integrate strip masses over [e1,e2] and return the 6x6 mass
%  matrix about their centroid c (wing frame).
    edges = linspace(e1,e2,nSub+1);
    Mq = zeros(6,6,nSub);  r = zeros(3,nSub);  w = zeros(1,nSub);
    for q = 1:nSub
        em  = 0.5*(edges(q)+edges(q+1));
        dL  = (edges(q+1)-edges(q)) * obj.EtaLength;
        sti = obj.AeroStations.interpolate(em);
        Xb  = obj.GetPos(em);  Xb = Xb(:);
        switch kind
            case "secondary"
                if ~sti.HasMass, continue, end
                dm = sti.LinearDensity * dL;
                Mq(:,:,q) = blkdiag(dm*eye(3), sti.LinearInertia*dL);
                r(:,q) = Xb + reshape(obj.AeroStations.GetPos(em,sti.MassLoc),3,1);
                w(q)   = dm;
            case "added"
                b  = sti.Chord/2;
                M  = diag([0,0,1]) * (0.5*rho*b^2*pi) * dL;
                I  = abs(diag(sti.EtaDir)) * rho*pi*b^4/8 * dL / norm(sti.EtaDir);
                Mq(:,:,q) = blkdiag(M,I);
                r(:,q) = Xb + reshape(obj.AeroStations.GetPos(em,0.5),3,1);
                w(q)   = M(3,3);
        end
    end
    has = any(w > 0);
    Mc = zeros(6);  c = zeros(3,1);
    if ~has, return, end
    c = r*w.' / sum(w);                           % mass-weighted centroid
    for q = find(w > 0)
        Mc = Mc + shiftMass(Mq(:,:,q), r(:,q) - c);
    end
end

% -------------------------------------------------------------------------

function Mo = shiftMass(M,d)
%SHIFTMASS  6x6 mass matrix defined at point P, re-referred to point O,
%  with d = P - O  (u_P = u_O + theta x d). Exact rigid transfer: gives the
%  parallel-axis terms and any translation/rotation coupling.
    S  = [0 -d(3) d(2); d(3) 0 -d(1); -d(2) d(1) 0];
    T  = [eye(3), -S; zeros(3), eye(3)];
    Mo = T.' * M * T;
end

% -------------------------------------------------------------------------

function v = getOpt(o,name,default)
    v = default;
    if (isobject(o) && isprop(o,name)) || (isstruct(o) && isfield(o,name))
        v = o.(name);
    end
end
