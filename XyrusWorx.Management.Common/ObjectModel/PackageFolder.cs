using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public abstract class PackageFolder
	{
		public abstract StringKey Key { get; }

		public StringKeySequence ChildFolder { get; set; }
	}
}