function ExtractIDs(obj,feModel)
%EXTRACTIDS Extract the relevant IDs from the provided feModel

%extract constraint IDs
if ~isempty(feModel.Constraints)
    obj.SPCs = [feModel.Constraints.ID];
else
    obj.SPCs = [];
end
end