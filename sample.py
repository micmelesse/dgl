from dgl.data.chem import Tox21, smiles_to_bigraph, CanonicalAtomFeaturizer
from dgl import model_zoo

dataset = Tox21(smiles_to_bigraph, CanonicalAtomFeaturizer())
model = model_zoo.chem.load_pretrained('GCN_Tox21') # Pretrained model loaded
model.eval()

smiles, g, label, mask = dataset[0]
feats = g.ndata.pop('h')
label_pred = model(g, feats)