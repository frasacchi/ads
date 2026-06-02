function [fe,Etas] = beam2fe(obj,baffOpts,opts)
arguments
    obj
    baffOpts ads.baff.BaffOpts = ads.baff.BaffOpts();
    opts.PointName string = ""
end
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

if ~issorted([obj.Stations.Eta])
    error('beam stations must be in ascending order with respect to Eta')
end

Etas = GetDiscreteEta(obj,baffOpts);
nodes = obj.GetPos(Etas);

c = 0;
for i = 1:length(Etas)
    fe.Points(i) = ads.fe.Point(nodes(:,i),InputCoordSys=CS,isAnchor=(i==1));
    fe.Forces(i)  = ads.fe.Force([0;0;0],fe.Points(i));
    fe.Points(i).Note = "AttachmentNode";

    % maybe remove this, Name might not be useful
    if strlength(opts.PointName) > 0
        fe.Points(i).Name = opts.PointName + "_N" + i;
    end

    if ~isempty(obj.ConstraintDoFs) && ~fe.Points(i).isAnchorPoint
        c = c + 1;
        fe.Constraints(c) = ads.fe.Constraint(fe.Points(i),obj.ConstraintDoFs);
    end
end

if obj.Stations.Mat(1).E == inf
    stations = obj.Stations.interpolate(Etas);
    for i = 1:length(stations)-1
        fe.RigidBars(end+1) = ads.fe.RigidBar(fe.Points(i),fe.Points(i+1));
    end
else
    fe.Materials(end+1) = ads.fe.Material.FromBaffMat(obj.Stations.Mat(1));
    stations = obj.Stations.interpolate(Etas);
    for i = 1:stations.N-1
        dir = stations.StationDir(:,i);
        dir = dir./norm(dir);
        A_in = fe.Points(i).InputCoordSys.getAglobal;
        A_out = fe.Points(i).OutputCoordSys.getAglobal;
        dir = A_out'*A_in*dir;
        fe.Beams(i) = ads.fe.Beam.FromBaffStations(stations.GetIndex(i:i+1),fe.Points(i:i+1),fe.Materials(end));
        fe.Beams(i).yDir = dir;
    end
    fe.DMIGs = ads.fe.DMIG.FromBaffStations(stations,fe.Points);
end

end
