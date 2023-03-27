function fe = point2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
fe = ads.fe.Component();
fe.Name = obj.Name;
fe.CoordSys(1) = ads.fe.CoordSys("Origin",obj.Offset,"A",obj.A);
CS = fe.CoordSys(1);

% generate nodes
for i = 1:length(obj)  
    fe.Points(i) = ads.fe.Point([0;0;0],"InputCoordSys",CS);
end

% generate Force and moments at each point
for i = 1:length(obj)
    if ~any(isnan(obj(i).Force))
        fe.Forces(i) = ads.fe.Force(obj(i).Force,fe.Points(i));
    end
    if ~any(isnan(obj(i).Moment))
        fe.Moments(i) = ads.fe.Moment(obj(i).Moment,fe.Points(i));
    end
end
end

