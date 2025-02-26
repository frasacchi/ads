function fe = wing2fe(obj,baffOpts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
end
% generate underlying beam FE
fe = beam2fe(obj,baffOpts);
Etas = GetDiscreteEta(obj,baffOpts);
% return if no aero panels reqeuired
if ~baffOpts.GenerateAeroPanels
    return
end
% check if wing has a flag to not generate aero panels
if isfield(obj.Meta,'ads') && isfield(obj.Meta.ads,'GenerateAeroPanels') && ~obj.Meta.ads.GenerateAeroPanels
    return
end

% get interpolated AeroSections
CS = fe.CoordSys(1);
idx = find(Etas>=obj.AeroStations(1).Eta & Etas<=obj.AeroStations(end).Eta);

%% update eta list to include breaks for control surfaces
% EtaControl = [];
% for i = 1:length(obj.ControlSurfaces)
%     EtaControl = [EtaControl,(obj.ControlSurfaces(i).Etas)'];
% end
% Etas = unique([Etas,EtaControl]);
%create Beam Nodes at each station
% add LE and TE points
function AddLeTe(obj,fe,Eta,Node)
    X = obj.GetPos(Eta);
    % add LE points
    X_le = obj.AeroStations.GetPos(Eta,0);
    fe.Points(end+1) = ads.fe.Point(X+X_le, InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
    % add TE points
    X_te = obj.AeroStations.GetPos(Eta,1);
    fe.Points(end+1) = ads.fe.Point(X+X_te, InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
end

% check a point will be added at the left of the wing
if abs(Etas(idx(1))-obj.AeroStations(1).Eta)>0.01
    [~,ii] = min(abs(Etas-obj.AeroStations(1).Eta));
    AddLeTe(obj,fe,obj.AeroStations(1).Eta,fe.Points(ii))
end
% add block of nodes
for i = 1:numel(idx)
    AddLeTe(obj,fe,Etas(idx(i)),fe.Points(idx(i)))
end
% check a point has been added at the left of the wing
if abs(Etas(idx(end))-obj.AeroStations(end).Eta)>0.01
    [~,ii] = min(abs(Etas-obj.AeroStations(end).Eta));
    AddLeTe(obj,fe,obj.AeroStations(end).Eta,fe.Points(ii))
end



%% update aerosurface list to include breaks for control surfaces
% find all etas
etas = unique([[obj.AeroStations.Eta],reshape([obj.ControlSurfaces.Etas],1,[])]);
aeroStations = obj.AeroStations.interpolate(etas);
%% Add aero surfaces
%create surfaces
for i = 1:(length(aeroStations)-1)
    bls = [aeroStations(i:(i+1)).BeamLoc];
    cs = [aeroStations(i:(i+1)).Chord];
    stEtas = [aeroStations(i:(i+1)).Eta];
    Twists = [aeroStations(i:(i+1)).Twist];
    Xs = [obj.GetPos(stEtas(1)),obj.GetPos(stEtas(2))];
    fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,bls,cs,StructuralPoints=fe.Points,...
        CoordSys=CS,Twists=Twists);
    vecs = [aeroStations(i).GetPos(nan,1)-aeroStations(i).GetPos(nan,0), ...
        aeroStations(i+1).GetPos(nan,1)-aeroStations(i+1).GetPos(nan,0)];
    fe.AeroSurfaces(i).ChordVecs = vecs./repmat(vecnorm(vecs),3,1);
    fe.AeroSurfaces(i).CrossEta = 0.5;
    fe.AeroSurfaces(i).LiftCurveSlope = aeroStations(i).LiftCurveSlope;
end

%% Add control surfaces to the aerosurfaces
cs_idx = ads.fe.Point.empty;
for i = 1:length(obj.ControlSurfaces)
    if obj.ControlSurfaces(i).pChord(1) ~=  obj.ControlSurfaces(i).pChord(2)
        error('For MSC Nastran the control surface must be a constant percentage of the chord')
    end
    fe.ControlSurfaces(i) = ads.fe.ControlSurface(obj.ControlSurfaces(i).Name);
    HingeEta = (1-obj.ControlSurfaces.pChord(1));

    % Code to set the control surface as its own rigid body so that it can be deformed in transient abalysis
    if baffOpts.SeperateSplineForControlSurfaces
        % first add two grid points to the wing to replace the TE points
        % and connect to beam
        % add etra point at LE of control surface
        X1 = obj.GetPos(obj.ControlSurfaces(i).Etas(1));
        X2 = obj.GetPos(obj.ControlSurfaces(i).Etas(2));
        X_h1 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),HingeEta);
        X_h2 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(end),HingeEta);


         % add second main wing point TE*
         fe.Points(end+1) = ads.fe.Point(X2+X_h2, InputCoordSys=CS,isAnchor=false,isAttachment=false);
         [~,idx] = min((Etas-obj.ControlSurfaces(i).Etas(2)).^2);
         fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idx),fe.Points(end));

        % add hinge coord system
        fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=obj.A*(obj.Offset+X1+X_h1),A=obj.A);
        % generate two coincedent nodes
        for ii = 1:2
            fe.Points(end+1) = ads.fe.Point(zeros(3,1),InputCoordSys=fe.CoordSys(end),OutputCoordSys=fe.CoordSys(end));
        end
        fe.Points(end-1).isAttachmentPoint = false;
        fe.Points(end).isAnchorPoint = false;

        % pin inboard of hinge
        [~,idx] = min((Etas-obj.ControlSurfaces(i).Etas(1)).^2);
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idx),fe.Points(end-1));

        %generate hinge
        fe.Hinges(end+1) = ads.fe.Hinge(fe.Points((end-1):end),fe.CoordSys(end),1e-3,0,isLocked=false);

        % add more points to wingtip
        Ail_point = fe.Points(end);
        fe.Points(end+1) = ads.fe.Point(X2+X_h2, InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
        add_p =2;
    
        %now add TE of control surface (only if they dont already exist...)
        if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(1)))
            fe.Points(end+1) = ads.fe.Point(X1+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),1), InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
             add_p = add_p + 1;
        end
        if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(2)))
            fe.Points(end+1) = ads.fe.Point(X2+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(2),1), InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
            add_p = add_p + 1;
        end

        % find TE nodes on the Aileron
        idx = find(Etas>=obj.ControlSurfaces(i).Etas(1) & Etas<=obj.ControlSurfaces(i).Etas(2));
        Ail_points = fe.Points([numel(Etas)+idx*2]);
        cs_idx = [cs_idx,Ail_points];
        fe.ControlSurfaces(i).StructuralPoints = [Ail_points;fe.Points((end-add_p+1):end)]; % TE points plus the two new points
        % remove rigid bars already connecting TE
        idx_bars = ~ismember([fe.RigidBars.Point2],Ail_points);
        fe.RigidBars = fe.RigidBars(idx_bars);
        % add new rigid bars
        for ii = 1:(length(Ail_points))
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,Ail_points(ii));
        end
        fe.Masses(end+1) = ads.fe.Mass(0,Ail_point,Ixx=1e-6);
    end
    % add aero panels on control surface to a list
    idx = 0;
    for j = 1:(length(aeroStations)-1)
        if aeroStations(j).Eta >= obj.ControlSurfaces(i).Etas(1) && aeroStations(j).Eta < obj.ControlSurfaces(i).Etas(2)
            fe.AeroSurfaces(j).ControlSurface = fe.ControlSurfaces(i);
            fe.AeroSurfaces(j).HingeEta = (1-obj.ControlSurfaces.pChord(1));
            idx = idx + 1;
            fe.ControlSurfaces(i).AeroSurfaces(idx) = fe.AeroSurfaces(j);
        end
    end
    if ~isempty(obj.ControlSurfaces(i).LinkedSurface)
        fe.ControlSurfaces(i).LinkedSurface = obj.ControlSurfaces(i).LinkedSurface.Name;
        fe.ControlSurfaces(i).LinkedCoefficent = obj.ControlSurfaces(i).LinkedCoefficent;
    end
end
% update structural nodes of main wing sections
% cs_idx = unique(cs_idx);
if ~isempty(cs_idx)
    % s_idx = ~ismember(1:numel(fe.Points),cs_idx);
    for i = 1:length(fe.AeroSurfaces)
        s_idx = ~ismember(fe.AeroSurfaces(i).StructuralPoints,Ail_points);
        fe.AeroSurfaces(i).StructuralPoints = fe.AeroSurfaces(i).StructuralPoints(s_idx);
    end
end
end

