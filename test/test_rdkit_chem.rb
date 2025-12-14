require 'test/unit'

require 'rdkit_chem'

class RDKitTest < Test::Unit::TestCase
  def test_mol_from_smiles
    smiles = 'CCO'  # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    assert_not_nil(rw_mol)
    assert_equal(3, rw_mol.get_num_atoms)
  end

  def test_mol_to_mol_block
    smiles = 'CCO'  # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    mdl = rw_mol.mol_to_mol_block(true, -1, false)
    assert_not_nil(mdl)
    assert(mdl.include?('V2000') || mdl.include?('V3000'))
  end

  def test_mol_from_mol_block
    smiles = 'c1ccccc1'  # benzene
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    mdl = rw_mol.mol_to_mol_block(true, -1, false)

    # Round-trip: mol block back to molecule
    mol_from_block = RDKitChem::RWMol.mol_from_mol_block(mdl)
    assert_not_nil(mol_from_block)
    assert_equal(6, mol_from_block.get_num_atoms)
  end

  def test_mol_to_smiles
    smiles = 'CCO'
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    output_smiles = RDKitChem.mol_to_smiles(rw_mol)
    assert_not_nil(output_smiles)
    assert_equal('CCO', output_smiles)
  end

  def test_cholesterol
    # Cholesterol without chirality
    smiles = 'CC(C)CCCC(C)C1CCC2C1(CCC3C2CC=C4C3(CCC(C4)O)C)C'
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    assert_not_nil(rw_mol)
    assert_equal(28, rw_mol.get_num_atoms)  # C27H46O has 28 heavy atoms (27 C + 1 O)
  end
end
