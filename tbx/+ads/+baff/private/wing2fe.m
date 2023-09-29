function fe = wing2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
% generate underlying beam FE
fe = beam2fe(obj,baffOpts);
Etas = GetDiscreteEta(obj,baffOpts);

if baffOpts.GenerateAeroPanels
    % get interpolated AeroSections
    CS = fe.CoordSys(1);
    %create LE and TE points at each Beam Node
    for i = 1:length(Etas)
        if Etas(i)<obj.AeroStations(1).Eta && Etas(i)<obj.AeroStations(end).Eta
            continue
        elseif Etas(i)>obj.AeroStations(1).Eta && Etas(i)>obj.AeroStations(end).Eta
            continue
        end
        Pa = fe.Points(i);
        X = obj.GetPos(Etas(i));
        % LE
        X_le = obj.AeroStations.GetPos(Etas(i),0);
        fe.Points(end+1) = ads.fe.Point(X+X_le, InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(Pa,fe.Points(end));
        % TE
        X_te = obj.AeroStations.GetPos(Etas(i),1);
        fe.Points(end+1) = ads.fe.Point(X+X_te, InputCoordSys=CS,isAnchor=false,isAttachment=false);
        fe.RigidBars(end+1) = ads.fe.RigidBar(Pa,fe.Points(end));
    end
    %% update aerosurface list to include breaks for control surfaces
    % find all etas
    etas = [obj.AeroStations.Eta];
    for i = 1:length(obj.ControlSurfaces)
        etas = [etas,(obj.ControlSurfaces(i).Etas)'];
    end
    etas = unique(etas);
    aeroStations = obj.AeroStations.interpolate(etas);
    %% Add aero surfaces
    %create surfaces
    for i = 1:(length(aeroStations)-1)
        bls = [aeroStations(i:(i+1)).BeamLoc];
        cs = [aeroStations(i:(i+1)).Chord];
        Etas = [aeroStations(i:(i+1)).Eta];
        Twists = [aeroStations(i:(i+1)).Twist];
        Xs = [obj.GetPos(Etas(1)),obj.GetPos(Etas(2))];
        fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,bls,cs,StructuralPoints=fe.Points,...
            CoordSys=CS,Twists=Twists); 
        vecs = [aeroStations(i).GetPos(nan,1)-aeroStations(i).GetPos(nan,0), ...
            aeroStations(i+1).GetPos(nan,1)-aeroStations(i+1).GetPos(nan,0)];
        fe.AeroSurfaces(i).ChordVecs = vecs./repmat(vecnorm(vecs),3,1);
        fe.AeroSurfaces(i).CrossEta = 0.5;
        fe.AeroSurfaces(i).LiftCurveSlope = aeroStations(i).LiftCurveSlope;
    end

    %% Add control surfaces to the aerosurfaces
    for i = 1:length(obj.ControlSurfaces)
        if obj.ControlSurfaces(i).pChord(1) ~=  obj.ControlSurfaces(i).pChord(2)
            error('For MSC Nastran the control surface must be a constant percentage of the chord')
        end
        fe.ControlSurfaces(i) = ads.fe.ControlSurface(obj.ControlSurfaces(i).Name);
        idx = 0;
        for j = 1:(length(aeroStations)-1)
            if aeroStations(j).Eta >= obj.ControlSurfaces(i).Etas(1) && aeroStations(j).Eta < obj.ControlSurfaces(i).Etas(2)
                fe.AeroSurfaces(j).HingeEta = (1-obj.ControlSurfaces.pChord(1));
                idx = idx + 1;
                fe.ControlSurfaces(i).AeroSurfaces(idx) = fe.AeroSurfaces(j);
            end
        end
    end
end
end

