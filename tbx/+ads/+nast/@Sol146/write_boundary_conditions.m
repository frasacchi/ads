function write_boundary_conditions(obj,fid)
% Locked_DoFs = laca.nastran.inv_dof(obj.DoFs);
% if ~isempty(Locked_DoFs)
%     mni.printing.cards.GRID(obj.CoM_GID,obj.CoM,'CP',obj.CoM_Cp).writeToFile(fid);
%     mni.printing.cards.RBE2(obj.CoM_GID,obj.CoM_GID,123456,obj.CoM_gp).writeToFile(fid);
%     mni.printing.cards.SPC1(100001,Locked_DoFs,obj.CoM_GID).writeToFile(fid);
% end
% if ~isempty(obj.DoFs)
%     mni.printing.cards.SUPORT(obj.CoM_GID,obj.DoFs).writeToFile(fid);
% end
end

