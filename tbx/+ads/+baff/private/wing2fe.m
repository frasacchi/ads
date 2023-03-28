function fe = wing2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
% generate underlying beam FE
fe = beam2fe(obj,baffOpts);
Etas = GetDiscreteEta(obj,baffOpts);

% get interpolated AeroSections
CS = fe.CoordSys(1);

%create LE and TE points at each Beam Node
for i = 1:length(Etas)
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
%% Add aero surfaces
for i = 1:(length(obj.AeroStations)-1)
    bls = [obj.AeroStations(i:(i+1)).BeamLoc];
    cs = [obj.AeroStations(i:(i+1)).Chord];
    Etas = [obj.AeroStations(i:(i+1)).Eta];
    Twists = [obj.AeroStations(i:(i+1)).Twist];
    Xs = [obj.GetPos(Etas(1)),obj.GetPos(Etas(2))];
    fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,bls,cs,StructuralPoints=fe.Points,...
        CoordSys=CS,Twists=Twists); 
end

end

