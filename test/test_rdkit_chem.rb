require "test/unit"

require "rdkit_chem"

class RDKitTest < Test::Unit::TestCase
  def test_mol_from_smiles
    smiles = "CCO"  # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    assert_not_nil(rw_mol)
    assert_equal(3, rw_mol.get_num_atoms)
  end

  def test_mol_to_mol_block
    smiles = "CCO"  # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    mdl = rw_mol.mol_to_mol_block(true, -1, false)
    assert_not_nil(mdl)
    assert(mdl.include?("V2000") || mdl.include?("V3000"))
  end

  def test_mol_from_mol_block
    smiles = "c1ccccc1" # benzene
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    mdl = rw_mol.mol_to_mol_block(true, -1, false)

    # Round-trip: mol block back to molecule
    mol_from_block = RDKitChem::RWMol.mol_from_mol_block(mdl)
    assert_not_nil(mol_from_block)
    assert_equal(6, mol_from_block.get_num_atoms)
  end

  def test_mol_to_smiles
    smiles = "CCO"
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    output_smiles = RDKitChem.mol_to_smiles(rw_mol)
    assert_not_nil(output_smiles)
    assert_equal("CCO", output_smiles)
  end

  def test_sanitize_mol
    smiles = "c1ccccc1" # benzene
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)

    # sanitize_mol returns an integer (0 for success usually, or bitmask of operations failed)
    # It might return different things based on SWIG wrapping details observed in MolOps.i
    # The SWIG wrapper returns the operation that failed (0 if all successful).
    result = RDKitChem.sanitize_mol(rw_mol, RDKitChem::SANITIZE_ALL)
    assert_equal(0, result, "sanitize_mol should return 0 (success)")

    result = RDKitChem.sanitize_mol(rw_mol)
    assert_equal(0, result, "sanitize_mol should return 0 (success)")
  end

  def test_cholesterol
    # Cholesterol without chirality
    smiles = "CC(C)CCCC(C)C1CCC2C1(CCC3C2CC=C4C3(CCC(C4)O)C)C"
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)
    assert_not_nil(rw_mol)
    assert_equal(28, rw_mol.get_num_atoms) # C27H46O has 28 heavy atoms (27 C + 1 O)
  end

  def test_conformer_ownership
    # FIXME: This test causes a segfault (exit code 139) likely due to GC/double-free issues.
    # Test that conformer ownership is properly transferred to the molecule.
    # This verifies the DISOWN directive works - without it, Ruby GC and C++
    # destructor both try to free the Conformer, causing a double-free segfault.
    smiles = "CCO" # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)

    # Create a conformer with 3D coordinates
    conf = RDKitChem::Conformer.new(rw_mol.get_num_atoms)
    conf.set_atom_pos(0, RDKitChem::Point3D.new(0.0, 0.0, 0.0))
    conf.set_atom_pos(1, RDKitChem::Point3D.new(1.5, 0.0, 0.0))
    conf.set_atom_pos(2, RDKitChem::Point3D.new(2.0, 1.0, 0.0))

    # Add conformer to molecule (ownership transfers to C++)
    conf_id = rw_mol.add_conf(conf, true)
    assert(conf_id >= 0, "Conformer should be added successfully")

    # Verify conformer was added
    assert_equal(1, rw_mol.get_num_conformers)

    # Access the conformer through the molecule
    retrieved_conf = rw_mol.get_conformer(conf_id)
    assert_not_nil(retrieved_conf)

    # Verify coordinates
    pos = retrieved_conf.get_atom_pos(0)
    assert_in_delta(0.0, pos.x, 0.001)
    assert_in_delta(0.0, pos.y, 0.001)
    assert_in_delta(0.0, pos.z, 0.001)

    # Force garbage collection to ensure no double-free occurs
    GC.start

    # The molecule should still be valid after GC
    assert_equal(3, rw_mol.get_num_atoms)
  end

  def test_conformer_ownership
    # Test that conformer ownership is properly transferred to the molecule.
    # This verifies the DISOWN directive works - without it, Ruby GC and C++
    # destructor both try to free the Conformer, causing a double-free segfault.
    smiles = 'CCO'  # ethanol
    rw_mol = RDKitChem::RWMol.mol_from_smiles(smiles)

    # Create a conformer with 3D coordinates
    conf = RDKitChem::Conformer.new(rw_mol.get_num_atoms)
    conf.set_atom_pos(0, RDKitChem::Point3D.new(0.0, 0.0, 0.0))
    conf.set_atom_pos(1, RDKitChem::Point3D.new(1.5, 0.0, 0.0))
    conf.set_atom_pos(2, RDKitChem::Point3D.new(2.0, 1.0, 0.0))

    # Add conformer to molecule (ownership transfers to C++)
    conf_id = rw_mol.addConf(conf, true)
    assert(conf_id >= 0, "Conformer should be added successfully")

    # Verify conformer was added
    assert_equal(1, rw_mol.get_num_conformers)

    # Access the conformer through the molecule
    retrieved_conf = rw_mol.get_conformer(conf_id)
    assert_not_nil(retrieved_conf)

    # Verify coordinates
    pos = retrieved_conf.get_atom_pos(0)
    assert_in_delta(0.0, pos.x, 0.001)
    assert_in_delta(0.0, pos.y, 0.001)
    assert_in_delta(0.0, pos.z, 0.001)

    # Force garbage collection to ensure no double-free occurs
    GC.start

    # The molecule should still be valid after GC
    assert_equal(3, rw_mol.get_num_atoms)
  end
end
