function fe = wing2fe(obj,baffOpts)
arguments
    obj
    baffOpts ads.baff.BaffOpts = ads.baff.BaffOpts();
end

if isa(obj.Stations,'baff.station.Beam') || isa(obj.Stations,'baff.station.SuperBeam')
    [fe,Etas] = beam2fe(obj,baffOpts,PointName=obj.Name);
    SplineType = 4;
elseif isa(obj.Stations,'baff.station.ShellStation.ShellStation')
    [fe,Etas] = shell2fe(obj,baffOpts,PointName=obj.Name);
    SplineType = 1;
end

if ~baffOpts.GenerateAeroPanels
    return
end
if isfield(obj.Meta,'ads') && isfield(obj.Meta.ads,'GenerateAeroPanels') && ~obj.Meta.ads.GenerateAeroPanels
    return
end

CS = fe.CoordSys(1);

% Capture structural attachment node indices before any LE/TE nodes are added
idxi = find([fe.Points.Note] == "AttachmentNode");

isWingtipLogic = isWingtip(obj);

%% Build (eta, structural node) pairs covering the aero span, then generate LE/TE nodes

aeroStart = obj.AeroStations.Eta(1);
aeroEnd   = obj.AeroStations.Eta(end);
idx = find(Etas >= aeroStart & Etas <= aeroEnd);

etas_proc   = Etas(idx);
points_proc = fe.Points(idxi(idx));

% Prepend a boundary station if the structural grid starts too far from the aero root
if abs(etas_proc(1) - aeroStart) > 0.01
    [~,ii]      = min(abs(Etas - aeroStart));
    etas_proc   = [aeroStart,            etas_proc  ];
    points_proc = [fe.Points(idxi(ii)),  points_proc];
end

% Append a boundary station if the structural grid ends too far from the aero tip
if abs(etas_proc(end) - aeroEnd) > 0.01
    [~,ii]      = min(abs(Etas - aeroEnd));
    etas_proc   = [etas_proc,   aeroEnd           ];
    points_proc = [points_proc, fe.Points(idxi(ii))];
end

for i = 1:numel(etas_proc)
    addLeTe(obj,fe,etas_proc(i),points_proc(i),isWingtipLogic)
end

%% Add aero surfaces (include control surface eta breaks)
etas = unique([obj.AeroStations.Eta, reshape([obj.ControlSurfaces.Etas],1,[])]);
st = obj.AeroStations.interpolate(etas);

idxA = find([fe.Points.Note] == "AttachmentNode");
for i = 1:(st.N-1)
    sts = st.GetIndex(i:(i+1));
    Xs  = [obj.GetPos(st.Eta(i)), obj.GetPos(st.Eta(i+1))];
    fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,sts.BeamLoc,sts.Chord, ...
        StructuralPoints=fe.Points,CoordSys=CS,Twists=sts.Twist);
    vecs = [st.GetPos(st.Eta(i),1)-st.GetPos(st.Eta(i),0), ...
            st.GetPos(st.Eta(i+1),1)-st.GetPos(st.Eta(i+1),0)];
    fe.AeroSurfaces(i).ChordVecs    = vecs ./ repmat(vecnorm(vecs),3,1);
    fe.AeroSurfaces(i).CrossEta     = 0.5;
    fe.AeroSurfaces(i).LiftCurveSlope = st.LiftCurveSlope(i);
    fe.AeroSurfaces(i).SplineType   = SplineType;
    if SplineType == 1
        fe.AeroSurfaces(i).StructuralPoints = fe.Points(idxA);
    end
end

%% Add secondary mass from aerodynamic stations
stMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.SecondaryMassStation+1));
for i = 1:(stMass.N-1)
    stEtas = stMass.Eta(i:(i+1));
    stEta  = mean(stEtas);
    sti    = stMass.interpolate(stEta);
    dL     = (stEtas(2)-stEtas(1)) * obj.EtaLength;
    if sti.HasMass
        X_m = obj.AeroStations.GetPos(stEta,sti.MassLoc) + obj.GetPos(stEta);
        fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        [~,midx] = min(abs(Etas - stEta));
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
        fe.Masses(end+1) = ads.fe.Mass(sti.LinearDensity.*dL,fe.Points(end), ...
            Ixx=sti.LinearInertia(1,1)*dL, Iyy=sti.LinearInertia(2,2)*dL, Izz=sti.LinearInertia(3,3)*dL, ...
            Ixy=sti.LinearInertia(1,2)*dL, Ixz=sti.LinearInertia(1,3)*dL, Iyz=sti.LinearInertia(2,3)*dL);
    end
end

%% Add aero added mass
if baffOpts.IncludeAeroAddedMass
    stAddedMass = obj.AeroStations.interpolate(linspace(aeroStart,aeroEnd,baffOpts.AddedMassStations+1));
    for i = 1:(stAddedMass.N-1)
        cs_chord = stAddedMass.Chord(i:(i+1));
        stEtas   = stAddedMass.Eta(i:(i+1));
        stEta    = mean(stEtas);
        sti      = stAddedMass.interpolate(stEta);
        dL       = (stEtas(2)-stEtas(1)) * obj.EtaLength;
        b        = mean(cs_chord) / 2;
        X_m = obj.AeroStations.GetPos(stEta,0.5) + obj.GetPos(stEta);
        fe.Points(end+1) = ads.fe.Point(X_m,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        [~,midx] = min(abs(Etas - stEta));
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(midx)),fe.Points(end));
        rho = baffOpts.AirDensity;
        M   = diag([0,0,1]) * (0.5*rho*b^2*pi) * dL;
        I   = abs(diag(sti.EtaDir)) * rho*pi*b^4/8 * dL / norm(sti.EtaDir);
        fe.Inertias(end+1) = ads.fe.Inertia(blkdiag(M,I),fe.Points(end));
    end
end

%% Add control surfaces
cs_idx = ads.fe.Point.empty;
for i = 1:length(obj.ControlSurfaces)
    if obj.ControlSurfaces(i).pChord(1) ~= obj.ControlSurfaces(i).pChord(2)
        error('For MSC Nastran the control surface must be a constant percentage of the chord')
    end
    fe.ControlSurfaces(i) = ads.fe.ControlSurface(obj.ControlSurfaces(i).Name);
    HingeEta = (1 - obj.ControlSurfaces.pChord(1));

    if baffOpts.SeperateSplineForControlSurfaces
        X1   = obj.GetPos(obj.ControlSurfaces(i).Etas(1));
        X2   = obj.GetPos(obj.ControlSurfaces(i).Etas(2));
        X_h1 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),HingeEta);
        X_h2 = obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(end),HingeEta);

        fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        [~,cidx] = min((Etas - obj.ControlSurfaces(i).Etas(2)).^2);
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end));

        fe.CoordSys(end+1) = ads.fe.CoordSys(Origin=obj.A*(obj.Offset+X1+X_h1),A=obj.A);
        for ii = 1:2
            fe.Points(end+1) = ads.fe.Point(zeros(3,1), ...
                InputCoordSys=fe.CoordSys(end),OutputCoordSys=fe.CoordSys(end));
        end
        fe.Points(end-1).isAttachmentPoint = false;
        fe.Points(end).isAnchorPoint       = false;

        [~,cidx] = min((Etas - obj.ControlSurfaces(i).Etas(1)).^2);
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(idxi(cidx)),fe.Points(end-1));

        fe.Hinges(end+1) = ads.fe.Hinge(fe.Points((end-1):end),fe.CoordSys(end),1e-3,0,isLocked=false);

        Ail_point = fe.Points(end);
        fe.Points(end+1) = ads.fe.Point(X2+X_h2,InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
        add_p = 2;

        if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(1)))
            fe.Points(end+1) = ads.fe.Point( ...
                X1+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(1),1), ...
                InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
            add_p = add_p + 1;
        end
        if ~any(ismember(Etas,obj.ControlSurfaces(i).Etas(2)))
            fe.Points(end+1) = ads.fe.Point( ...
                X2+obj.AeroStations.GetPos(obj.ControlSurfaces(i).Etas(2),1), ...
                InputCoordSys=CS,isAnchor=false,isAttachment=false);
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,fe.Points(end));
            add_p = add_p + 1;
        end

        cidx_range = find(Etas>=obj.ControlSurfaces(i).Etas(1) & Etas<=obj.ControlSurfaces(i).Etas(2));
        Ail_points = fe.Points(numel(Etas)+cidx_range*2);
        cs_idx(end+1:end+numel(Ail_points)) = Ail_points;
        fe.ControlSurfaces(i).StructuralPoints = [Ail_points; fe.Points((end-add_p+1):end)];
        idx_bars = ~ismember([fe.RigidBars.Point2],Ail_points);
        fe.RigidBars = fe.RigidBars(idx_bars);
        for ii = 1:length(Ail_points)
            fe.RigidBars(end+1) = ads.fe.RigidBar(Ail_point,Ail_points(ii));
        end
        fe.Masses(end+1) = ads.fe.Mass(0,Ail_point,Ixx=1e-6);
    end

    idx_cs = 0;
    for j = 1:(st.N-1)
        if st.Eta(j) >= obj.ControlSurfaces(i).Etas(1) && st.Eta(j) < obj.ControlSurfaces(i).Etas(2)
            fe.AeroSurfaces(j).ControlSurface = fe.ControlSurfaces(i);
            fe.AeroSurfaces(j).HingeEta       = (1-obj.ControlSurfaces.pChord(1));
            idx_cs = idx_cs + 1;
            fe.ControlSurfaces(i).AeroSurfaces(idx_cs) = fe.AeroSurfaces(j);
        end
    end
    if ~isempty(obj.ControlSurfaces(i).LinkedSurface)
        fe.ControlSurfaces(i).LinkedSurface    = obj.ControlSurfaces(i).LinkedSurface.Name;
        fe.ControlSurfaces(i).LinkedCoefficent = obj.ControlSurfaces(i).LinkedCoefficent;
    end
end

if ~isempty(cs_idx)
    for i = 1:length(fe.AeroSurfaces)
        s_idx = ~ismember(fe.AeroSurfaces(i).StructuralPoints,Ail_points);
        fe.AeroSurfaces(i).StructuralPoints = fe.AeroSurfaces(i).StructuralPoints(s_idx);
    end
end

end

% -------------------------------------------------------------------------

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

function addLeTe(obj,fe,Eta,Node,isWingtip)

    [X,Dir] = obj.GetPos(Eta);
    chordDir = cross(Dir, cross(Dir, [0,1,0]))';

    X_le = obj.AeroStations.GetPos(Eta,0);
    X_te = obj.AeroStations.GetPos(Eta,1);

    Etai = norm(Dir(2:3)/norm(Dir)) * norm(X_te) / obj.EtaLength;
    Xi_te = X+(Dir(1) / norm(Dir)) * norm(X_te)*chordDir/norm(chordDir);
    Xi_le = X-(Dir(1) / norm(Dir)) * norm(X_le)*chordDir/norm(chordDir);

    if Xi_te(2)>Xi_le(2)
        Xi_te = X-(Dir(1) / norm(Dir)) * norm(X_te)*chordDir/norm(chordDir);
        Xi_le = X+(Dir(1) / norm(Dir)) * norm(X_le)*chordDir/norm(chordDir);
    end

    if Eta < Etai || (Eta > (1-Etai) && ~isWingtip)
        return
    end

    if Eta == 1 && isWingtip
        Xi_le = X+X_le;
        Xi_te = X+X_te;
    end

    CS = Node.InputCoordSys;
    fe.Points(end+1) = ads.fe.Point(Xi_le,InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.Points(end).Tag = "AttachmentNode";
    fe.Points(end).Name = obj.Name + "_LE";
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));

    fe.Points(end+1) = ads.fe.Point(Xi_te,InputCoordSys=CS,isAnchor=false,isAttachment=false);
    fe.Points(end).Tag = "AttachmentNode";
    fe.Points(end).Name = obj.Name + "_TE";
    fe.RigidBars(end+1) = ads.fe.RigidBar(Node,fe.Points(end));
end
