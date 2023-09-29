function fe = mass2fe(obj,baffOpts)
    arguments
        obj
        baffOpts = ads.baff.BaffOpts();
    end
fe = point2fe(obj,baffOpts);
for i = 1:length(obj)
    % generate mass
    fe.Masses(i) = ads.fe.Mass(obj(i).mass,fe.Points(i));
    fe.Masses(i).InertiaTensor = obj(i).InertiaTensor;
end
end

