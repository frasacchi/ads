function fe = mass2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
fe = point2fe(obj,baffOpts);
for i = 1:length(obj)
    % generate mass
    fe.Masses(i) = ads.fe.Mass(obj(i).GetElementMass,fe.Points(i));
    fe.Masses(i).InertiaTensor = obj(i).InertiaTensor;
    fe.Masses(i).Name = obj(i).Name;
end
end

