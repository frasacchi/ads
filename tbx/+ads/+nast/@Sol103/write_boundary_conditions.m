function write_boundary_conditions(obj,fid)
    mni.printing.bdf.writeComment(fid, 'Boundary Conditions')
    mni.printing.bdf.writeColumnDelimiter(fid,'8');
    spcs = obj.SPCs;
    if obj.isFree
        Locked_DoFs = ads.nast.inv_dof(obj.DoFs);
        if ~isempty(Locked_DoFs)
            mni.printing.cards.GRID(obj.CoM_GID,obj.CoM.GlobalPos).writeToFile(fid);
            mni.printing.cards.RBE2(obj.CoM_RBE_ID,obj.CoM_GID,123456,obj.CoM.ID).writeToFile(fid);
            mni.printing.cards.SPC1(obj.CoM_SPC_ID,Locked_DoFs,obj.CoM_GID).writeToFile(fid);
            spcs = [spcs,obj.CoM_SPC_ID];
        end
        if ~isempty(obj.DoFs)
            mni.printing.cards.SUPORT(obj.CoM_GID,obj.DoFs).writeToFile(fid);
        end
    end
    mni.printing.cards.SPCADD(obj.SPC_ID,spcs).writeToFile(fid);
end

