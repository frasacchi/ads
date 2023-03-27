function fe = ElementFactory(obj,baffOpts)
arguments
    obj
    baffOpts = ads.baff.BaffOpts();
end
switch class(obj)
    case 'baff.Beam'
        fe = beam2fe(obj,baffOpts);
    case 'baff.BluffBody'
        fe = bluff2fe(obj,baffOpts);
    case 'baff.Constraint'
        fe = constraint2fe(obj,baffOpts);
    case 'baff.Hinge'
        fe = hinge2fe(obj,baffOpts);
    case 'baff.Mass'
        fe = mass2fe(obj,baffOpts);
    case 'baff.Point'
        fe = point2fe(obj,baffOpts);
    case 'baff.Wing'
        fe = wing2fe(obj,baffOpts);
    otherwise
        error('No Method availble for baff type %s',class(obj))
end
end

