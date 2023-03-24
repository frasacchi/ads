function [fe,AnchorPoints] = wing2fe(obj,opts)
arguments
    obj baff.Wing
    opts.BeamElements = 10;
end
% generate underlying beam FE
[fe,AnchorPoints] = beam2fe(obj,"NumElements",opts.BeamElements);
Etas = GetDiscreteEta(obj,opts.BeamElements);

% get interpolated AeroSections
CS = fe.CoordSys(1);

%create LE and TE points at each Beam Node
AeroPoints  = AnchorPoints(1:end);
for i = 1:length(Etas)
    Pa = AnchorPoints(i);
    X = obj.GetPos(Etas(i));
    % LE
    X_le = obj.AeroStations.GetPos(Etas(i),0);
    fe.Points(end+1) = ads.fe.Point(X+X_le, InputCoordSys=CS);
    fe.RigidBars(end+1) = ads.fe.RigidBar(Pa,fe.Points(end));
    % TE
    X_te = obj.AeroStations.GetPos(Etas(i),1);
    fe.Points(end+1) = ads.fe.Point(X+X_te, InputCoordSys=CS);
    fe.RigidBars(end+1) = ads.fe.RigidBar(Pa,fe.Points(end));

    % add point to Aero Points
    AeroPoints = [AeroPoints;fe.Points((end-1):end)];
end

%% Add aero surfaces
for i = 1:(length(obj.AeroStations)-1)
    bls = [obj.AeroStations(i:(i+1)).BeamLoc];
    cs = [obj.AeroStations(i:(i+1)).Chord];
    Etas = [obj.AeroStations(i:(i+1)).Eta];
    Twists = [obj.AeroStations(i:(i+1)).Twist];
    Xs = [obj.GetPos(Etas(1)),obj.GetPos(Etas(2))];
    fe.AeroSurfaces(i) = ads.fe.AeroSurface(Xs,bls,cs,StructuralPoints=AeroPoints,...
        CoordSys=CS,Twists=Twists); 
%     fe.AeroSurfaces(i).nChord = obj.ChordDensity;
%     fe.AeroSurfaces(i).nSpan = obj.SpanDensity;
end

end

