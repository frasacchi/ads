function [fe,AnchorPoints] = ElementFactory(obj)
%ELEMENTFACTORY Summary of this function goes here
%   Detailed explanation goes here
switch class(obj)
    case 'baff.Beam'
        [fe,AnchorPoints] = beam2fe(obj);
    case 'baff.BluffBody'
        [fe,AnchorPoints] = bluff2fe(obj);
    case 'baff.Constraint'
        [fe,AnchorPoints] = constraint2fe(obj);
    case 'baff.Hinge'
        [fe,AnchorPoints] = hinge2fe(obj);
    case 'baff.Mass'
        [fe,AnchorPoints] = mass2fe(obj);
    case 'baff.Point'
        [fe,AnchorPoints] = point2fe(obj);
    case 'baff.Wing'
        [fe,AnchorPoints] = wing2fe(obj);
    otherwise
        error('No Method availble for baff type %s',class(obj))
end
end

