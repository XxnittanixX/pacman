using JetBrains.Annotations;

namespace XyrusWorx.Management.ObjectModel
{
	[PublicAPI]
	public class PackageLibFolder : PackageFolder
	{
		public sealed override StringKey Key => "lib";
	}
}