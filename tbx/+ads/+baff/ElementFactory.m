function fe = ElementFactory(obj,baffOpts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
end
if isa(obj,'baff.Wing')
    fe = wing2fe(obj,baffOpts);
elseif isa(obj,'baff.Beam')
    fe = beam2fe(obj,baffOpts);
elseif isa(obj,'baff.BluffBody')
    fe = bluff2fe(obj,baffOpts);
elseif isa(obj,'baff.Constraint')
    fe = constraint2fe(obj,baffOpts);
elseif isa(obj,'baff.Hinge')
    fe = hinge2fe(obj,baffOpts);
elseif isa(obj,'baff.Mass')
    fe = mass2fe(obj,baffOpts);
elseif isa(obj,'baff.Point')
    fe = point2fe(obj,baffOpts);
else
    error('No Method availble for baff type %s',class(obj))
end
end

